#!/bin/sh
#=========================================================

#=========================================================
echo "Install the packages..."
#=========================================================
sudo apt-get update
sudo apt-get -y install fluxbox xorg unzip vim default-jre rungetty firefox

#=========================================================
echo "Set autologin for the Vagrant user..."
#=========================================================
sudo sed -i '$ d' /etc/init/tty1.conf
sudo echo "exec /sbin/rungetty --autologin vagrant tty1" >> /etc/init/tty1.conf

#=========================================================
echo -n "Start X on login..."
#=========================================================
PROFILE_STRING=$(cat <<EOF
if [ ! -e "/tmp/.X0-lock" ] ; then
    startx
fi
EOF
)
echo "${PROFILE_STRING}" >> .profile
echo "ok"

#=========================================================
echo "Download chrome..."
#=========================================================
wget "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo rm google-chrome-stable_current_amd64.deb
sudo apt-get install -y -f

#=========================================================
echo "Download selenium server..."
#=========================================================
SELENIUM_VERSION=$(curl "https://selenium-release.storage.googleapis.com/" | perl -n -e'/.*<Key>([^>]+selenium-server-standalone-2[^<]+)/ && print $1')
wget "https://selenium-release.storage.googleapis.com/${SELENIUM_VERSION}" -O selenium-server-standalone.jar
chown vagrant:vagrant selenium-server-standalone.jar

#=========================================================
echo "Download chrome driver..."
#=========================================================
CHROMEDRIVER_VERSION=$(curl "http://chromedriver.storage.googleapis.com/LATEST_RELEASE")
wget "http://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip"
unzip chromedriver_linux64.zip
sudo rm chromedriver_linux64.zip
chown vagrant:vagrant chromedriver

#=========================================================
echo -n "Install tmux script hub..."
#=========================================================
echo '{
  "_comment" : "Configuration for Hub - hubConfig.json",
  "host": 104.196.44.21,
  "maxSessions": 10,
  "port": 4444,
  "cleanupCycle": 5000,
  "timeout": 300000,
  "newSessionWaitTimeout": -1,
  "servlets": [],
  "prioritizer": null,
  "capabilityMatcher": "org.openqa.grid.internal.utils.DefaultCapabilityMatcher",
  "throwOnCapabilityNotPresent": true,
  "nodePolling": 180000,
  "platform": "LINUX"
}' >> hubConfig.json
TMUX_SCRIPT_HUB=$(cat <<EOF
#!/bin/sh
tmux start-server
tmux new-session -d -s hub
tmux send-keys -t hub:0 'java -jar selenium-server-standalone.jar -role hub -hubConfig hubConfig.json -Dwebdriver.chrome.driver=/home/vagrant/chromedriver > /home/vagrant/selenium-hub.log' C-m
EOF
)
echo "${TMUX_SCRIPT_HUB}" > tmux_hub.sh
chmod +x tmux_hub.sh
chown vagrant:vagrant tmux_hub.sh
echo "ok"

#=========================================================
echo -n "Install tmux script node..."
#=========================================================
echo '{
  "capabilities": [
    {
      "browserName": "chrome",
      "maxInstances": 10,
      "platform": "LINUX",
      "webdriver.chrome.driver": "/home/vagrant/chromedriver"
    }
  ],
  "configuration": {
    "_comment" : "Configuration for Node",
    "cleanUpCycle": 2000,
    "timeout": 60000,
    "port": 5555,
    "host": localhost,
    "register": true,
    "hubPort": 4444,
    "maxSessions": 10
  }
}' >> nodeConfig.json
TMUX_SCRIPT_NODE=$(cat <<EOF
#!/bin/sh
tmux start-server
tmux new-session -d -s node
tmux send-keys -t node:0 'java -jar selenium-server-standalone.jar -role node -nodeConfig nodeConfig.json -Dwebdriver.chrome.bin=/usr/bin/google-chrome Dwebdriver.chrome.driver=/home/vagrant/chromedriver > /home/vagrant/selenium-node.log' C-m
EOF
)
echo "${TMUX_SCRIPT_NODE}" > tmux_node.sh
chmod +x tmux_node.sh
chown vagrant:vagrant tmux_node.sh
echo "ok"

#=========================================================
echo -n "Install startup scripts..."
#=========================================================
STARTUP_SCRIPT_HUB=$(cat <<EOF
#!/bin/sh
~/tmux_hub.sh &
xterm &
EOF
)
echo "${STARTUP_SCRIPT_HUB}" > /etc/X11/Xsession.d/9999-common_start_hub
chmod +x /etc/X11/Xsession.d/9999-common_start_hub

STARTUP_SCRIPT_NODE=$(cat <<EOF
#!/bin/sh
~/tmux_node.sh &
xterm &
EOF
)
echo "${STARTUP_SCRIPT_NODE}" > /etc/X11/Xsession.d/9999-common_start_node
chmod +x /etc/X11/Xsession.d/9999-common_start_node

echo "ok"

#=========================================================
echo -n "Add host alias..."
#=========================================================
echo "192.168.44.21 host" >> /etc/hosts
echo "ok"

#=========================================================
echo "Reboot the VM"
#=========================================================
sudo reboot
