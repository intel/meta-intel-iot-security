import unittest
import re
import os
import string
from oeqa.oetest import oeRuntimeTest, skipModule
from oeqa.utils.decorators import *

def get_files_dir():
    """Get directory of supporting files"""
    pkgarch = oeRuntimeTest.tc.d.getVar('MACHINE', True)
    deploydir = oeRuntimeTest.tc.d.getVar('DEPLOY_DIR', True)
    return os.path.join(deploydir, "files", "target", pkgarch)


@tag(TestType = 'Functional Positive', FeatureID = 'IOTOS-807')
class AppPrivilege(oeRuntimeTest):

	def setUp(self):
		self.user = "app-privilege-user"
		idcmd="id -u %s" %self.user
		status, output = self.target.run(idcmd)
		if status:
			status, output = self.target.run("adduser -D %s" %self.user)
			self.assertFalse(status, msg="Adding app-privilege-user failed: %s" %output)
			status, output = self.target.run(idcmd)

		self.assertTrue(output.isdigit(), msg="Unexpected output from %s: %s" %(idcmd, output))
		self.uid = output
		self.pkgid = "test-app-privilege"
		self.label = "test_label"
		self.files_dir = os.path.join(
			            os.path.abspath(os.path.dirname(__file__)), 'files')
                status, output = self.target.run( "ls /tmp/notroot.py")
                if status != 0:
                        self.target.copy_to(
                                os.path.join(
                                        self.files_dir, "notroot.py"),
                                        "/tmp/notroot.py")
		status, output = self.target.run( "ls /tmp/app-runas")
		if status != 0: 
			self.target.copy_to( 
				os.path.join(get_files_dir(), "app-runas"),
				"/tmp/app-runas")
					
		status, output = self.target.run("grep smack /proc/mounts | awk '{print $2}'")
	        self.smack_path = output

                status, self.ping = self.target.run("which ping")
                self.assertEqual(status, 0, "Ping not available")

	
	def setRule(self, rule):
		self.target.run("echo '%s' > %s/load" %(rule, self.smack_path)) 

        def test_local_network_no_access(self):

		# make sure no access is allowed 
		#     12345678901234567890123456789012345678901234567890123456
		rule1="test_label              Network::Local          -----"
		rule2="Network::Local          test_label              -----"
		self.setRule(rule1)
		self.setRule(rule2)
		status, output = self.target.run("python /tmp/notroot.py %s %s %s -c 3 %s"
						  %(self.uid, self.label, self.ping,  self.target.server_ip))
		self.assertIn("ping: sendto: Permission denied", output, "Ping succeeded when it should have failed")

	def test_local_network_write_access_oneway(self):
		
		# set write access to network, but network should not have write access to test label
		rule1="test_label              Network::Local          -w---"
                rule2="Network::Local          test_label              -----"
                self.setRule(rule1)
                self.setRule(rule2)

		status, output = self.target.run("python /tmp/notroot.py %s %s %s -c 3 %s"
                                                  %(self.uid, self.label, self.ping,  self.target.server_ip))
                self.assertIn("3 packets transmitted, 0 packets received, 100% packet loss", output, "Ping should have had 100% packet loss")		
						
	def test_local_network_write_access_both(self):
		rule1="test_label              Network::Local          -w---"
                rule2="Network::Local          test_label              -w---"
                self.setRule(rule1)
                self.setRule(rule2)

                status, output = self.target.run("python /tmp/notroot.py %s %s %s -c 3 %s"
                                                  %(self.uid, self.label, self.ping,  self.target.server_ip))
                self.assertIn("3 packets transmitted, 3 packets received, 0% packet loss", output, "All ping packets should have been sent and responses received")
	
	def test_app_without_network_privilege(self):
		""" Check if application without network privilege can access the network"""
		
		appid = "test-app-no-network-privilege"
		# install app
		self.target.run("/tmp/app-runas -a %s -p %s -u %s -i" % \
				(appid, self.pkgid, self.uid))
		status, output = self.target.run("/tmp/app-runas -a %s -u %s -e -- sh -c 'ping -c 3 %s'" % \
				(appid, self.uid, self.target.server_ip))
		
		self.assertIn("3 packets transmitted, 0 packets received, 100% packet loss", output, "Application without network privilege can access to network")
		
		
	def test_app_with_network_privilege(self):
		""" Check if application with network privilege can access the network"""

                appid = "test-app-with-network-privilege"
                # install app
                self.target.run("/tmp/app-runas -a %s -p %s -u %s -r LocalNetworkAccess -i" % \
                                (appid, self.pkgid, self.uid))
                status, output = self.target.run("/tmp/app-runas -a %s -u %s -e -- sh -c 'ping -c 3 %s'" % \
                                (appid, self.uid, self.target.server_ip))
                
		self.assertIn("3 packets transmitted, 3 packets received, 0% packet loss", output, "Application with network privilege cannot access network")
		

