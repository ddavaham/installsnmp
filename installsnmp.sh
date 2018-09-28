#!/bin/bash

echo -e "From which location will this device be monitored?\n"
echo -e "1) Allentown     2) Denver\n"
read -p 'Enter your choice: ' input

if [ "$input" == "1" ]
then
	hosts[0]="localhost"
	hosts[1]="209.235.239.73"
	hosts[2]="209.235.239.74"
	hosts[3]="209.235.239.75"
	hosts[4]="209.235.239.76"
	hosts[5]="209.235.239.82"
	hosts[6]="209.235.239.83"
	hosts[7]="192.168.227.122"

elif [ "$input" == "2" ]
then
	hosts[0]="localhost"
	hosts[1]="74.63.159.92"
	hosts[2]="74.63.159.93"
	hosts[3]="74.63.159.94"
	hosts[4]="74.63.159.95"
	hosts[5]="74.63.159.104"
	hosts[6]="74.63.159.105"

else
	echo "Please rerun the script and choose 1 or 2 only"
	exit 1
fi

echo ""
read -p 'Enter the desired community string: ' communityString
echo ""

echo -e "SNMP Services will be configured as follows:\n"
echo -e "Community String: $communityString\n"
echo "Accepted Hosts:"
for value in "${hosts[@]}"
do
	echo $value
done
echo ""
read -p 'Continue and make changes [y/n]? ' -n 1 -r
echo ""
if [[ $REPLY =~ ^[^Yy]*$ ]]
then
	echo "Exiting Script. No changes made"
	exit 1
fi

echo "<==Determining OS==>"

if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    ...
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    ...
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

echo $OS
echo $VER

#distro=$(sudo cat /etc/*-release)

if [ "$OS" == "CentOS Linux" ] && [ "$VER" > 6 ] 
then
	echo "<==RHEL, CENTOS DETECTED==>"
	echo "<==VERIFY SNMP INSTALL==>"
	yum list installed net-snmp net-snmp-utils > /dev/null 2> /dev/null
	if [ $? == "1" ]
	then
        echo -e "<==INSTALLING SNMP==>\n"
    	sudo yum -y install net-snmp net-snmp-utils
	else
	echo "<==SNMP ALREADY PRESENT==>"
	fi
elif [ "$OS" == "CentOS Linux" ] && [ "$VER" <= 6 ]
then
	echo "<==RHEL, CENTOS DETECTED==>"
	echo "<==VERIFY SNMP INSTALL==>"
	yum list installed net-snmp net-snmp-utils > /dev/null 2> /dev/null
	if [ $? == "1" ]
	then
        echo -e "<==INSTALLING SNMP==>\n"
    	sudo yum -y install net-snmp net-snmp-utils
	else
	echo "<==SNMP ALREADY PRESENT==>"
	fi
elif [ "$OS" == "Red Hat Enterprise Linux" ] && [ "$VER" <= 6 ]
then
	echo "<==RHEL, CENTOS DETECTED==>"
	echo "<==VERIFY SNMP INSTALL==>"
	yum list installed net-snmp net-snmp-utils > /dev/null 2> /dev/null
	if [ $? == "1" ]
	then
        echo -e "<==INSTALLING SNMP==>\n"
    	sudo yum -y install net-snmp net-snmp-utils
	else
	echo "<==SNMP ALREADY PRESENT==>"
	fi
elif [ "$OS" == "Red Hat Enterprise Linux" ] && [ "$VER" > 6 ]
then
	echo "<==RHEL, CENTOS DETECTED==>"
	echo "<==VERIFY SNMP INSTALL==>"
	yum list installed net-snmp net-snmp-utils > /dev/null 2> /dev/null
	if [ $? == "1" ]
	then
        echo -e "<==INSTALLING SNMP==>\n"
    	sudo yum -y install net-snmp net-snmp-utils
	else
	echo "<==SNMP ALREADY PRESENT==>"
	fi	
elif [ "$OS" == "Ubuntu" ]
then
	echo "<==UBUNTU DETECTED==>"
	echo "<==VERIFY SNMP INSTALL==>"
	check=$(sudo apt list --installed | grep -i snmpd)
	if [ -z "$check" ]
	then
        echo -e "<==INSTALLING SNMP==>\n"
    	sudo apt-get -y install snmpd
	else
	echo "<==SNMP ALREADY PRESENT==>"
	fi
else
	echo "Neither RHEL, CENTOS, or UBUNTU Detected, please install SNMP Manually"
	exit 1
fi

echo "<==BACKING UP SNMP CONF==>"

if [ ! -f /etc/snmp/snmpd.conf ]
then
    echo "Unable to determine if /etc/snmp/snmpd.conf exists. Exiting Script"
    exit 1
fi

cp /etc/snmp/snmpd.conf /etc/snmp/snmpd_conf_bkup

if [ ! -f /etc/snmp/snmpd_conf_bkup ]
then
    echo "SNMP Configuration back up failed. Exiting Script"
    exit 1
fi

echo "<==APPENDING POLLING SERVERS==>"

for value in "${hosts[@]}"
do
	l=$(cat /etc/snmp/snmpd.conf | grep -i $value)
    if [ -z "$l" ]
    then
        echo "rocommunity $communityString $value" >> /etc/snmp/snmpd.conf
    else
        echo " Found $value in current configuration."
    fi
done

echo "<==RESTARTING SNMP SERVICES==>"

if [ "$OS" == "CentOS Linux" ] && [ "$VER" > 6 ]
then
	sudo systemctl restart snmpd
elif [ "$OS" == "CentOS Linux" ] && [ "$VER" < 6 ]
then
	sudo service restart snmpd
elif [ "$OS" == "Red Hat Enterprise Linux" ] && [ "$VER" <= 6 ]
then
	sudo service restart snmpd
elif [ "$OS" == "Red Hat Enterprise Linux" ] && [ "$VER" > 6 ]
then	
	sudo systemctl restart snmpd
elif [ "$OS" == "Ubuntu" ]
then
    sudo systemctl restart snmpd
fi

echo "<==SETTING SNMP TO START ON BOOT==>"

if [ "$OS" == "CentOS Linux" ] && [ "$VER" > 6 ]
then
	sudo systemctl enable snmpd
elif [ "$OS" == "CentOS Linux" ] && [ "$VER" < 6 ]
then
	sudo service enable snmpd
elif [ "$OS" == "Red Hat Enterprise Linux" ] && [ "$VER" <= 6 ]
then
	sudo service enable snmpd
elif [ "$OS" == "Red Hat Enterprise Linux" ] && [ "$VER" > 6 ]
then	
	sudo systemctl enable snmpd
elif [ "$OS" == "Ubuntu" ]
then
    sudo systemctl enable snmpd
fi

echo "<==CHECKING IF IPTABLES IS ENABLED==>"



echo "<==SCRIPT COMPLETED: Please check history for correct operation==>"