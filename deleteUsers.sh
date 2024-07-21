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
# 1 : Failed to delete users from specific user caused the error to the end of the list due to errors with userdel command
# 2 : exceeds number of users to be deleted per script which is 9 users


#getting number of users to be deleted
echo -n  "Enter number of users to be deleted: "
read NUM
isINT $NUM "you have exceeded the limit which is 9 users" 2

for((i=0; i<NUM; i++));
do

# getting usernames ...
        echo -n "Enter a username: "
        read CURUSER
        echo ""

#deleting user ...
	sudo userdel -r $CURUSER
        if [ $? -ne 0 ]; then
		echo "ERROR in deleting users from ${CURUSER} to the end of the list which explained above" && exit 1
        fi
done

echo "All users are deleted successfully"

exit 0
