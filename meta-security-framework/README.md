This README file contains information on the contents of the
security-framework layer.

Please see the corresponding sections below for details.


Dependencies
============

This layer depends on:

  URI: git://git.openembedded.org/bitbake
  branch: master

  URI: git://git.openembedded.org/openembedded-core
  layers: meta
  branch: master

  URI: git://github.com/01org/meta-security-smack
  layers: security-smack
  branch: master


Patches
=======

Please submit any patches against the security-framework layer via
Github pull requests.

Maintainer: Patrick Ohly <patrick.ohly@intel.com>


Table of Contents
=================

  I. Adding the security-framework layer to your build
 II. Misc


I. Adding the security-framework layer to your build
====================================================

In order to use this layer, you need to make the build system aware of
it.

Assuming the security repository exists at the top-level of your
yocto build tree, you can add it to the build system by adding the
location of the security-framework layer to bblayers.conf, along with any
other layers needed. e.g.:

  BBLAYERS ?= " \
    /path/to/yocto/meta \
    /path/to/yocto/meta-yocto \
    /path/to/yocto/meta-yocto-bsp \
    /path/to/yocto/meta-security-smack/meta-security-smack \
    /path/to/yocto/meta-security-smack/meta-security-framework \
    "


II. Misc
========

Conceptually, the components in this layer are optional in a
Smack-based security architecture and thus sit on top of the
meta-framework-smack layer. This layer here is meant for Cynara,
security-manager and the Cynara-aware D-Bus.

In practice, Cynara itself is independent of Smack and only needs to
be installed properly when using Smack. The components using Cynara
then use Smack labels as identifiers for the entity trying to get a
certain permission.
