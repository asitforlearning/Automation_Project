#!/bin/bash
######################Asit.K 28-05-2021###################################
##script for automating apache server updates and service state
##########################################################################

#variables to initialize START
s3_bucket='upgrad-asit'
myname='asit'

timestamp=`date '+%d%m%Y-%H%M%S'`
##log path to track execution details of this script
automation_log=/tmp/automation_script_log.txt
#variables to initialize END


echo "START run @ $timestamp*******************************">>$automation_log


## arguments: first parameter as status of command and rest as command text that was fired to log
function exit_on_fail {
	if [[ $1 -eq 0 ]] 
	then
		echo "${timestamp}: Success code ${1} for command $2." >>$automation_log
	else
		echo "${timestamp}: Command ${2} failed with return code ${1} exiting process." >>$automation_log
		exit  $1
	fi
}

## update packages
sudo apt update -y
status=$?
exit_on_fail $status "apt update -y"



##check and install apache2 if not already installed
dpkg --get-selections | grep apache
pkgfound=$?

if [[ $pkgfound -eq 0 ]] 
then
	echo "${timestamp}: Apache package was already found to be installed." >>$automation_log
else
	echo "${timestamp}: Installing apache package." >>$automation_log
	apt-get  install --yes apache2
	status=$?
	exit_on_fail $status " apt  install apache2"
fi


##check apache2 process status start if not running
ps -ef|grep 'apache2 -k start'|grep -v grep
apache_status=$?

if [[ $apache_status -eq 0 ]] 
then
	echo "${timestamp}: apache2 process is already running" >>$automation_log
else
	echo "${timestamp}: starting apache2" >>$automation_log
	service apache2 start
	status=$?
	exit_on_fail $status " service apache2 start"
fi

##creating tar for log files
archive_name=/tmp/${myname}-httpd-logs-${timestamp}.tar
tar cvf  $archive_name --wildcards -C /var/log/apache2/  access.log error.log


## log archive copy to s3 bucket  
if [[ -f  $archive_name ]] 
then
	aws s3 \
	cp /tmp/${myname}-httpd-logs-${timestamp}.tar \
	s3://${s3_bucket}/${myname}-httpd-logs-${timestamp}.tar
	status=$?
	exit_on_fail $status " aws s3 copy of ${archive_name}"
else
	echo "logs archive file $archive_name  was not available." >>$automation_log
fi	
	
echo "END run @ $timestamp*******************************">>$automation_log

