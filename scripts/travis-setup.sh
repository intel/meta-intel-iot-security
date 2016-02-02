#! /bin/bash
#
# Invoke this script as
# [SSTATE_CACHE/DOWNLOADS=<path to directory persistent sstates-cache and downloads dirs>] \
# [AWS_BUCKET=... AWS_BUCKET_REGION=...] \
# [OE_CORE=OE-core branch name] \
# [BITBAKE=bitbake branch name] \
# travis-setup.sh [<directory>]
# and it'll set up that directory such that '. init-travis-build-env'
# can be invoked in it.
#
# That directory is supposed to be empty or at most contain a a copy
# of the meta-intel-iot-security repository.

set -ex

LAYERDIR=$(dirname $0)/..
SRC_DIR=${1-$(pwd)}
INIT=$SRC_DIR/init-travis-build-env

mkdir -p $SRC_DIR
cd $SRC_DIR
git clone --depth=1 --single-branch --branch=${OE_CORE:-master} https://github.com/openembedded/openembedded-core.git
( cd openembedded-core && git clone --depth=1 --single-branch --branch=${BITBAKE:-master} https://github.com/openembedded/bitbake.git )

# Out-of-tree builds.
if [ $SRC_DIR != $LAYERDIR ]; then
    for i in $(ls -1 $LAYERDIR); do
        ln -s $LAYERDIR/$i .
    done
fi

# Detect whether we run under Travis or on some other machine.
if [ "$TRAVIS" != "true" ]; then
    buildenv="native"
elif uname -a | grep -q 3.13; then
    buildenv="traviscontainer"
else
    buildenv="travistrusty"
fi
echo "buildenv=$buildenv" >>$INIT

# The container environment has an limit of 2 hours per run. Everything else
# only gets 50 minutes.
#
# If we get killed, our sstate will not be uploaded and we won't be
# faster during the next invocation either. Therefore abort bitbake
# invocations which take too long ourselves, and then upload new
# sstate. We reserve 10 minutes for that (five was not enough
# sometimes).
start=$(date +%s)
case $buildenv in
    traviscontainer) duration=120;;
    travistrusty) duration=50;;
    *) duration=0;;
esac
if [ $duration -gt 0 ]; then
    deadline=$(( $start + $duration * 60 - 10 * 60 ))
    echo "Started on $(date --date=@$start), must end at $(date --date=@$deadline)."
else
    # Must set something. A week should be enough.
    deadline=$(( $start + 7 * 24 * 60 * 60))
fi
echo "deadline=$deadline" >>$INIT

echo ". $SRC_DIR/openembedded-core/oe-init-build-env $SRC_DIR/build" >>$INIT
# This only works correctly in bash, hence /bin/bash.
. openembedded-core/oe-init-build-env $SRC_DIR/build

# Reuse downloads and/or sstate.
if [ "$DOWNLOADS" ]; then
    mkdir -p "$DOWNLOADS"
    ln -s "$DOWNLOADS" downloads
fi
if [ "$SSTATE_CACHE" ]; then
    mkdir -p "$SSTATE_CACHE"
    ln -s "$SSTATE_CACHE" sstate-cache
fi

sed -i -e "s;\(BBLAYERS.*\"\);\1 $SRC_DIR/meta-security-smack $SRC_DIR/meta-security-framework $SRC_DIR/meta-integrity;" conf/bblayers.conf

cat >>conf/local.conf <<EOF
# Simplify qemu compilation.
PACKAGECONFIG_remove_pn-qemu-native = "sdl"
ASSUME_PROVIDED_remove = "libsdl-native"

# Enable security components.
DISTRO_FEATURES_append = " systemd pam smack dbus-cynara ima"
OVERRIDES .= ":smack"
VIRTUAL-RUNTIME_init_manager = "systemd"
DISTRO_FEATURES_BACKFILL_CONSIDERED = "sysvinit"
VIRTUAL-RUNTIME_initscripts = ""
CORE_IMAGE_EXTRA_INSTALL_append_pn-core-image-minimal = " smack-userspace security-manager security-manager-policy cynara app-runas"
INHERIT_append_pn-core-image-minimal = " ima-evm-rootfs"

# Dump information about sstate usage.
INHERIT += "buildstats-summary"

# For testing...
EXTRA_IMAGE_FEATURES = "debug-tweaks ssh-server-dropbear"
CORE_IMAGE_EXTRA_INSTALL_append_pn-core-image-minimal = " python"
EOF

# Use Amazon S3 bucket as sstate cache if available.
if [ -n "$AWS_BUCKET" ]; then
    echo "SSTATE_MIRRORS = \"file://.* http://$AWS_BUCKET.s3-website-${AWS_BUCKET_REGION:-us-east-1}.amazonaws.com/PATH\"" >>conf/local.conf
fi

case $buildenv in
    travis*)
        cat >>conf/local.conf <<EOF
# Can monitor less directories (it is all one file system) and
# accept lower security margins, because a failure is not that
# critical.
BB_DISKMON_DIRS = " STOPTASKS,/tmp,500M,10K STOPTASKS,\${DL_DIR},500M,10K ABORT,/tmp,100M,1K ABORT,\${DL_DIR},100M,1K"
# Useful to avoid running out of disk space during the build.
INHERIT += "rm_work_and_downloads"
BB_SCHEDULERS = "rmwork.RunQueueSchedulerRmWork"
BB_SCHEDULER = "rmwork"
EOF

        cp ../scripts/rm_work_and_downloads.bbclass classes
        mkdir classes
        echo "PYTHONPATH=$TRAVIS_BUILD_DIR/scripts" >>$INIT
        echo "export PYTHONPATH" >>$INIT

        # Even with rm_work in place, running too many tasks in parallel can
        # cause the disk to overflow temporarily and/or trigger the
        # out-of-memory killer, so we allow only two tasks.  The default is
        # too large because /proc/cpuinfo is misleading: it seems to show
        # all CPUs on the host, although in reality (?) the environments only have
        # two, according to
        # http://docs.travis-ci.com/user/ci-environment/#Virtualization-environments
        #
        # The Trusty Beta environment has more RAM and thus can afford more parallelism.
        # However, it also has a shorter overall runtime. If we end up with two heavy
        # compile tasks (say, linux-yocto and qemu-native), then both compete for CPU
        # time and neither of them manages to complete before the job gets killed.
        # The solution for this is in the custom scheduler: it can limit the number of
        # compile tasks separately from other tasks. This allows us to run many light-weight
        # tasks (like setscene) in parallel without overloading the machine when compiling.
        # However, we now may end up with 32 different recipes unpacked and ready for
        # compilation, which takes up more disk space again.
        case $buildenv in
            traviscontainer)
                cat >>conf/local.conf <<EOF
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j4"
EOF
                ;;
            travistrusty)
                cat >>conf/local.conf <<EOF
BB_NUMBER_COMPILE_THREADS = "1"
PARALLEL_MAKE = "-j8"
EOF
                ;;
        esac
        ;;
esac
