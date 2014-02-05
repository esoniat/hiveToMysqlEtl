#!/bin/bash
# 
#
scriptDir=$(realpath ${0%/*})
sshTestRunLog="allSSH.log"


function usage() {
    cat <<EOF
 usage:$0 options 
 Runs the ssh checker logging to the directory 
 provided as the -t argument

 OPTIONS:
  -h Show this message
  -t Specify directory for the log

EOF
}

#
# Main
#
unset sshTaskDirectory
while getopts "ht:" opt; do
    case $opt  in
	t)
	    sshWorkingDirectory=${OPTARG}
	    ;;
	?)xo
	    usage >> ${sshTestRunLog}
	    exit 1
	    ;;

    esac
done
#
# get to the left overs (not that we need them now
shift $((OPTIND -1))
if [[ -z ${sshWorkingDirectory} ]] ; then
    echo "$(date) The log directory must be specified"
    usage  >> ${sshTestRunLog}
    exit 1
fi

cd ${sshWorkingDirectory}
echo "$(date) ${0}" >> ${sshTestRunLog}


# the directory this script is in.
sshServerUserName="esoniat"
destinationBaseDir="adHocEtl"
# Only hosts with pub keys should be used.
sshHostList="slpr-aha01.lpdomain.com ropr-aha01.lpdomain.com svpr-aha01.lpdomain.com"
scpTestDir="${destinationBaseDir}/${sshWorkingDirectory}"
testScpFileName="lastScpTest.date"
#echo "$(date) checking hosts ${sshHostList}" >> ${sshTestRunLog}
for sshHost in ${sshHostList} ; do
    date > ${testScpFileName}
    echo "$(date) testing ${sshHost}" >> ${sshTestRunLog}
    sshCmd="ssh -oBatchMode=yes ${sshServerUserName}@${sshHost} \"mkdir -vp ${scpTestDir}\"/"
    eval ${sshCmd}  >> ${sshTestRunLog} 2>&1
    if [[ $? -ne 0 ]] ; then 
        echo "$(date) FAILED ${sshCMD}" >> ${sshTestRunLog}
    else  
        sshCmd="scp -oBatchMode=yes ${testScpFileName} ${sshServerUserName}@${sshHost}:${scpTestDir}/."
         eval ${sshCmd}  >> ${sshTestRunLog} 2>&1
        if [[ $? -ne 0 ]] ; then
            echo "$(date) FAILED ${sshCMD}" >> ${sshTestRunLog}
        else
            echo "$(date) PASSED ${sshHost}" >> ${sshTestRunLog}
        fi
    fi
done	 
echo "$(date) All ssh hosts have been tested " >> ${sshTestRunLog}
