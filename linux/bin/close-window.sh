#!/bin/bash
# shellcheck disable=all

if [ "$#" -ne 1 ]; then
	echo -e "\e[31mWindow name not provided\e[0m"
	exit 1
fi

appname=$1

i=0                      #set "counting var" to 0
while true; do           #do as long as I say
	i=$(echo $i + 1)        #add 1 to i
	wmctrl -F -c "$appname" #close window with exact title "WhatsDesk"
	if [ $? -eq 0 ]; then   #if close window command was successful, do:
		break                  #end "while"
	else
		if ((i == 40)); then #if "counting var" = x, do:
			break               #end "while"
		else
			sleep 0.25 #pause "while" for x seconds
		fi
	fi
done
