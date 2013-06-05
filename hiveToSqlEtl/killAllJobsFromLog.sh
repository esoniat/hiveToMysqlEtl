#!/bin/bash
# for al of the log files collect and execute the kill commands
#
for file in *.log; do 
	 killLine=$(grep "Kill Command" ${file})
	 killCmd=$(echo ${killLine} | sed 's/Kill Command = /\n/g')
	 eval "${killCmd}"
done
