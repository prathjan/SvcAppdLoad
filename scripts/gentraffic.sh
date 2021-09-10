#!/bin/sh
apt install openjdk-8-jdk -y
cd /tmp
tar xvf apache-jmeter-5.4.1.tgz 
#cd apache-jmeter-5.4.1/bin
#cp /tmp/teastore_browse_nogui.jmx .
java -jar ./apache-jmeter-5.4.1/bin/ApacheJMeter.jar -t teastore_browse_nogui.jmx -Jhostname 10.88.168.212 -Jport 8085 -JnumUser 10 -JrampUp 1 -l mylogfile.log -n



