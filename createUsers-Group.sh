#!/bin/bash

## Function check for value is an integer (only one digit)
function isINT {
	local VAL="${1}"
	local MSG="${2}"
	local EXITCODE="${3}"
	RES=$(echo "${VAL}" | grep -cE '^[0-9]$')
	[ ${RES} -ne 1 ] && echo "${MSG}" && exit ${EXITCODE}
}

# Exit codes
# 0 : success
# 1 : Failed to create from specific user caused the error to the end of the list  due to errors with adduser command 
# 2 : exceeds number of users to be created per script which is 9 users



###if you want to get number of users to be created uncomment these 3 lines and comment the 4th line
#echo -n  "Enter number of users to be created: "
#read NUM
#isINT $NUM "you have exceeded the limit which is 9 users" 2

NUM=3

#getting group name ...
echo -n "Enter the group: "
read GRP
echo ""
[ -z "$(grep -q $GRP  /etc/group)" ] && sudo groupadd $GRP


for((i=0; i<NUM; i++));
do

# getting usernames and passwords ... 	
	echo -n "Enter a username: "
        read CURUSER
	echo ""
	echo -n "Enter a password: "
        read -s CURPASS
	echo ""
	HASHEDPASS=$(sudo openssl passwd -6 "${CURPASS}")

# creating users ...
        sudo adduser -s /bin/bash -p ${HASHEDPASS}  -md /home/${CURUSER} ${CURUSER}
        if [ $? -ne 0 ]; then
       		echo "ERROR in creating users from $CURUSER that caused the error to the end of the list  which explained above" && exit 1
	fi       	
	
#adding users to the group ...
	sudo usermod -aG $GRP $CURUSER

done

echo "All users are created and added to the group successfully"


exit 0
