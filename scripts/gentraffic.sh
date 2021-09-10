#!/bin/sh
echo "ip is $1"
echo "port is $2"
apt install openjdk-8-jdk -y
cd /tmp
tar xvf apache-jmeter-5.4.1.tgz 
#cd apache-jmeter-5.4.1/bin
#cp /tmp/teastore_browse_nogui.jmx .
java -jar ./apache-jmeter-5.4.1/bin/ApacheJMeter.jar -t teastore_browse_nogui.jmx -Jhostname $1 -Jport $2 -JnumUser 10 -JrampUp 1 -l mylogfile.log -n



