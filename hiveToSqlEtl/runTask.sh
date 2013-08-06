# This runs the tasks in a specific task directory
#
hiveResultTopDir="adHocEtl"
scriptDir=${0%/*}
killHiveScript="killAllJobsFromLog.sh"
# check for and report errors in the config.
# exit after checking all variables
function checkConfig() {
    missingVariable="false"
    if [[ -z ${hiveFileName} ]] ; then
	    echo "hiveFileName not set"
	    missingVariable="true"
    fi
    if [[ -z ${hiveServer} ]] ; then
	    echo "hiveServer not set"
	    missingVariable="true"
    fi
    if [[ -z ${hiveServerUserName} ]] ; then
	    echo "hiveServerUserName not set"
	    missingVariable="true"
    fi
    if [[ -z ${hiveResultFileName} ]] ; then
	    echo "hiveResultFilePath not set"
	    missingVariable="true"
    fi
    if [[ -z ${sqlFileName} ]] ; then
	    echo "sqlFileName not set"
	    missingVariable="true"
    fi
    if [[ -z ${sqlServer} ]] ; then
	    echo "sqlServer not set"
	    missingVariable="true"
    fi
    if [[ -z ${sqlUser} ]] ; then
	    echo "sqlUser not set"
	    missingVariable="true"
    fi
    if [[ -z ${sqlPassword} ]] ; then
	    echo "sqlPassword not set"
	    missingVariable="true"
    fi
    if [[ "${missingVariable}" = "true" ]] ; then
	    echo "One or more configuration values not set"
    fi
}

# The first argument is  directory for the results
function runHiveAndSql() {
    allTaskDir=${1}
    taskDir=${2}
	unset debugMode
	if [[ ${allTaskDir} == *testTaskDirectory* ]] ; then
		debugMode="true"
	fi
    # make a unique dir for all task 
    hiveDir=$(cygpath -u "${hiveResultTopDir}/${allTaskDir}/${taskDir}")
    let sshStatus=1
    # get a unique name for each file
    fileRoot="$(uuidgen)"
    # add the extensions
    resultFileName="${fileRoot}.result"
    logFileName="${fileRoot}.log"
    tempHiveFileName="${fileRoot}.hive"
    # Check end of file (last 2 lines for "OK" or " Ended Job.* with errors"
    # before cleaningup
    let maxTrys=5
    let taskFailCount=0
    # set these to 1 to get in to the while loop
    let hiveStatus=1
    let sshStatus=1
    while [[ ${sshStatus} -ne 0 && ${hiveStatus} -ne 0  && ${taskFailCount} -lt ${maxTrys} ]]; do 
        # reset to success until proven otherwise
        let hiveStatus=0
        let sshStatus=0
        echo "$(date) Starting attempt ${taskFailCount} of ${hiveFileName} taskId: ${fileRoot}"
        # Make the directory as needed
        ssh ${hiveServerUserName}@${hiveServer} "mkdir -vp ${hiveDir}"
        let "sshStatus|=$?"
        # copy over the hive file
        echo "$(date) Copied ${hiveFileName} to ${hiveServerUserName}@${hiveServer}:${hiveDir}/${tempHiveFileName}"
        scp ${hiveFileName} ${hiveServerUserName}@${hiveServer}:${hiveDir}/${tempHiveFileName}
        let "sshStatus|=$?"
        # run the hive file
        ssh ${hiveServerUserName}@${hiveServer} "cd ${hiveDir};cat ${tempHiveFileName} >> ${logFileName}"
        let "sshStatus|=$?"
        echo "$(date) Starting ${hiveServer}:${hiveDir}/${tempHiveFileName}"
	    ssh ${hiveServerUserName}@${hiveServer} "cd ${hiveDir};hive  -hiveconf mapred.map.child.java.opts=-Xmx2048M  -f ${tempHiveFileName} > ${resultFileName} 2>> ${logFileName}"
        let "sshStatus|=$?"
        echo "$(date) Retrieving ${hiveServerUserName}@${hiveServer}:${hiveDir}/${logFileName} "
	    scp ${hiveServerUserName}@${hiveServer}:${hiveDir}/${logFileName} ${logFileName}
        let "sshStatus|=$?"
        echo "Stauts test${sshStatus} -eq 0 && -f ${logFileName} "
        # if it seems we got the log file check it
        if [[ ${sshStatus} -eq 0 && -f ${logFileName}  ]] ; then
            #FIXME:  This does not catch problems with multiple queries.
	        #tail -5 $logFileName | grep -q "^OK"
            # look for the two known error lines anywhere in the file
            hiveStatus=0
            if grep -q "^Ended Job.*with errors$" $logFileName ; then
                hiveStatus=1
            elif grep -q "^FAILED:.* return code " $logFileName ; then
                hiveStatus=1
            fi
            if [[ ${hiveStatus} -ne 0 ]] ; then
                echo "$(date) Attempt ${taskFailCount} failed. Killing jobs in ${logFileName}"
                scp ${scriptDir}/${killHiveScript} ${hiveServerUserName}@${hiveServer}:${hiveDir}/${killHiveScript}
                ssh ${hiveServerUserName}@${hiveServer} "cd ${hiveDir}; chmod +x ${killHiveScript}; cat ${logFileName}|./${killHiveScript}"
                sleep 10
            else
	            echo "$(date) Retrieving result ${hiveServerUserName}@${hiveServer}:${hiveDir}/${resultFileName}"
	            scp ${hiveServerUserName}@${hiveServer}:${hiveDir}/${resultFileName} ${hiveResultFileName}
                let "sshStatus|=$?"
                if [[ ${sshStatus} -ne 0 ]] ; then
                    echo "$(date) Failed retrieving results"
                fi
                cat ${hiveResultFileName} | lzop -c > ${hiveResultFileName}.lzo
            fi
        else
            echo "$(date) Failed retrieving log file"
            # No log file we have to assume the hive failed
            hiveStatus=1
        fi

        if [[ ${sshStatus} -ne 0 || ${haveStatus} -ne 0 ]] ; then
	        let taskFailCount=taskFailCount+1            
        fi
    done
    if [[ ${taskFailCount} -ne 0 ]] ; then
        echo "$(date) ${tempHiveFileName} failed ${taskFailCount} times"
    fi
    if [[ ${hiveStatus} -ne 0 ]] ; then
	    echo "$(date) ERROR ${tempHiveFileName} never succeeded"
	    return 1
    elif [[ ${sshStatus} -ne 0 ]] ; then
        echo "$(date) ERROR one or more ssh command never succeeded"
        return 1
    else
        echo "$(date) Finished ${tempHiveFileName} with no apparent errors"
    fi

    echo "$(date) Removing files from ${hiveServerUserName}@${hiveServer}:${hiveDir}"
    ssh ${hiveServerUserName}@${hiveServer} "cd ${hiveDir};rm -f ${resultFileName} ${logFileName} ${tempHiveFileName}"

    let mysqlStatus=1
    let mysqlTryCount=0

    #&& [[ "${mysqlTryCount}" -lt "${maxTrys}"]] ]] ;  do
    while [[ ${mysqlStatus} -ne 0  && ${mysqlTryCount} -lt ${maxTrys} ]]; do 
        echo "$(date) attemp ${mysqlTrCount} task ${fileRoot} loading data from ${resultFileName} with ${PWD}/${sqlFileName}"
	    mysql --local-infile -h${sqlServer} -u${sqlUser} -p${sqlPassword} < ${sqlFileName} 2>&1
	    mysqlStatus=$?
	    let mysqlTryCount=mysqlTryCount+1
	    sleep 5
    done
    # If mysql failed save the result so that it can be used to recover or debug.
    if [[ ${mysqlStatus} -ne 0 ]] ; then
	    echo "$(date) Task ${fileRoot} sql error failed ${mysqlTryCount} times, saving hive results in ${fileRoot}_${hiveResultFileName}"
        cp ${hiveResultFileName} ${fileRoot}_${hiveResultFileName}
    else
        echo "$(date) Task ${fileRoot} successfully loaded data"
    fi
    # if in debug mode alwasy safe the result
	if [[ ! -z ${debugMode} ]] ; then
		echo "$(date) Debug mode, saving results in ${fileRoot}_${hiveResultFileName}"
        cp ${hiveResultFileName} ${fileRoot}_${hiveResultFileName}
    fi
    # cleanup the result, it has been copied above
    rm ${hiveResultFileName}

}
# MAIN
allTasksDirectory=${1}
taskDir=${2}
etlConfigFileName=${3}
. ${etlConfigFileName}
# if we do not get any strings back then execute the task
checkResult="$(checkConfig)"
if [[ -z ${checkResult}  ]] ; then
	echo "$(date) Executing etl task in ${taskDir}"
	runHiveAndSql ${allTasksDirectory} ${taskDir}
	echo "$(date) Finished etl task in ${taskDir}"
else
	echo "$(date) ${checkResult}"
fi
