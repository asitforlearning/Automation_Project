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
inventory_file=/var/www/html/inventory.html
cron_entry="1 0 * * *	root	/root/Automation_Project/automation.sh"
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

##changes for Version 2  / task 3 START checking/initializing inventory_file
if [[ -f $inventory_file ]]
then
	echo "${timestamp}: $inventory_file is present" >>$automation_log
else
	echo "Log Type			Time Created			Type			Size">>$inventory_file
	status=$?
	exit_on_fail $status " creation of $inventory_file"
fi
##changes for Version 2  / task 3 FINISH checking/initializing  inventory_file

##creating tar for log files
archive_name=/tmp/${myname}-httpd-logs-${timestamp}.tar
tar cvf  $archive_name --wildcards -C /var/log/apache2/  access.log error.log


## log archive copy to s3 bucket  
if [[ -f  $archive_name ]] 
then
	##changes for Version 2  / task 3 START  writing archive status
	file_size=`du -h $archive_name|cut -f1`
	echo "httpd-logs			${timestamp}			tar			$file_size">>$inventory_file
	##changes for Version 2  / task 3 END  writing archive status
	aws s3 \
	cp /tmp/${myname}-httpd-logs-${timestamp}.tar \
	s3://${s3_bucket}/${myname}-httpd-logs-${timestamp}.tar
	status=$?
	exit_on_fail $status " aws s3 copy of ${archive_name}"
else
	echo "logs archive file $archive_name  was not available." >>$automation_log
fi	


##changes for Version 2  / task 3 START  creating crontab entry
jobs_temp_file=/tmp/cronf_file
#store existing jobs to cron file
crontab -l>${jobs_temp_file}
cron_file_exists=$?

if [[ $cron_file_exists -eq 0 ]] 
then
	echo "${timestamp}: cron jobs file exists for user" >>$automation_log
else
	##remove verbose text
	echo "">${jobs_temp_file}
fi

grep '/root/Automation_Project/automation.sh' ${jobs_temp_file}
cron_automation_entry_exists=$?

if [[ $cron_automation_entry_exists -eq 0 ]] 
then
	echo "${timestamp}: cron job entry already exists for automation task" >>$automation_log
else
	echo "${cron_entry}">>${jobs_temp_file}
	crontab ${jobs_temp_file}
	status=$?
	exit_on_fail $status " cron entry creation for automation task"
fi
##changes for Version 2  / task 3 END  creating crontab entry

echo "END run @ $timestamp*******************************">>$automation_log

