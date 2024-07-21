#!/bin/bash

GRPNAME=deployG

#if you want to get group name as an input uncomment these three lines
#echo 'Enter group name: '
#read GRPNAME
#echo ''

#get users in the group
USERSIN=$(grep $GRPNAME /etc/group | cut -d: -f4 | sed 's/,/|/g')
#echo $USERSIN
#get users not inside the group
grep -vE $USERSIN /etc/passwd | cut -d: -f1

exit 0
