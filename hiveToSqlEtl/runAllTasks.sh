#!/bin/bash
# 
# This script will go through all of the directories in the
# task directory.  Any directory containing a hiveEtlConfig file 
# will be considered a task and using the hiveEtlConfig the
# files in that directory as specified in the hiveEtlConfig
# will be used to perform a hive to mysql ETL.
#
etlConfigFileName="hiveEtlConfig"
hiveResultTopDir="adHocEtl"
function usage() {
    cat <<EOF
 usage:$0 options 
 Runs all of the etl task as defined in subdirectoryes
 of the taskDir (-1)

 OPTIONS:
  -h Show this message
  -t Specify directory containing etl task directories

EOF
}
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
    # make a unique dir for all task 
    hiveDir="${hiveResultTopDir}/${allTaskDir}/${taskDir}"
    echo "a:${allTaskDir}  t:${taskDir} h:${hiveDir}"
    # get a unique name for each file
    fileRoot="$(uuidgen)"
    # add the extensions
    resultFileName="${fileRoot}.result"
    logFileName="${fileRoot}.log"
    tempHiveFileName="${fileRoot}.hive"
    # Make the directory as needed
    ssh ${hiveServerUserName}@${hiveServer} "mkdir -p "${hiveDir}
    # copy over the hive file
    echo "Copied ${hiveFileName} to ${hiveServerUserName}@${hiveServer}:${hiveDir}/${tempHiveFileName}"
    scp ${hiveFileName} ${hiveServerUserName}@${hiveServer}:${hiveDir}/${tempHiveFileName}
    # run the hive file
    ssh ${hiveServerUserName}@${hiveServer} "cd ${hiveDir};cat ${tempHiveFileName} >> ${logFileName}"
    # Check end of file (last 2 lines for "OK" or " Ended Job.* with errors"
    # before cleaningup
    let maxTrys=5
    let hiveStatus=1
    let hiveTryCout=0
    while [[ ${hiveStatus} -ne 0  && ${hiveTryCount} -lt ${maxTrys} ]]; do 
	    ssh ${hiveServerUserName}@${hiveServer} "cd ${hiveDir};hive -f ${tempHiveFileName} > ${resultFileName} 2>> ${logFileName}"
	    # get the results
	    echo "Retrieving ${hiveServerUserName}@${hiveServer}:${hiveDir}/${resultFileName} and log file"
	    scp ${hiveServerUserName}@${hiveServer}:${hiveDir}/${resultFileName} ${hiveResultFileName}
	    scp ${hiveServerUserName}@${hiveServer}:${hiveDir}/${logFileName} ${logFileName}
	    #Look for ok at the end of the file
	    tail $logFileName | grep -q "^OK"
	    hiveStatus=$?
	    let hiveTryCount=hiveTryCount+1
	    sleep 5
    done
    if [[ ${hiveStatus} -ne 0 ]] ; then
	    echo "hive error failed ${hiveTryCount} times"
	    return 1
    fi

    echo "Removing files from ${hiveServerUserName}@${hiveServer}:${hiveDir}"
    ssh ${hiveServerUserName}@${hiveServer} "cd ${hiveDir};rm -f ${resultFileName} ${logFileName} ${tempHiveFileName}"
    echo "Loading data from ${sqlPassword} with ${PWD}/${sqlFileName}"
    let mysqlStatus=1
    let mysqlTryCount=0

    #&& [[ "${mysqlTryCount}" -lt "${maxTrys}"]] ]] ;  do
    while [[ ${mysqlStatus} -ne 0  && ${mysqlTryCount} -lt ${maxTrys} ]]; do 
	    mysql --local-infile -h${sqlServer} -u${sqlUser} -p${sqlPassword} < ${sqlFileName}
	    mysqlStatus=$?
	    let mysqlTryCount=mysqlTryCount+1
	    sleep 5
    done
    if [[ ${mysqlStatus} -ne 0 ]] ; then
	    echo "sql error failed ${mysqlTryCount} times"
	    return 1
    else
	    echo "Keeping results ${hiveResultFileName}"
	    #rm ${hiveResultFileName}
    fi
}

#
# Main
#
unset allTasksDirectory
while getopts "ht:" opt; do
    case $opt  in
	    t)
	        allTasksDirectory=${OPTARG}
	        ;;
	    ?)
	        usage
	        exit 1
	        ;;

    esac
done
#
# get to the left overs (not that we need them now
shift $((OPTIND -1))
if [[ -z ${allTasksDirectory} ]] ; then
    echo "The task directory must be specified"
    usage
    exit 1
fi
cd ${allTasksDirectory}
echo "Running tasks found in $PWD"
for taskDir in * ; do
    # Quitly ignore files
    if [[ ! -d ${taskDir} ]] ; then
	    continue;
    fi
    # Inform about dirs that do not have config files.
    if [[ ! -f $taskDir/${etlConfigFileName} ]] ; then
	    echo "Skiping ${taskDir}. No ${etlConfigFileName} found"
    else
	    cd ${taskDir}
	    . ${etlConfigFileName}
	    # if we don't get any strings back then execute the task
	    checkResult="$(checkConfig)"
	    if [[ -z ${checkResult}  ]] ; then
	        echo "Executing etl task in ${taskDir}"
	        runHiveAndSql ${allTasksDirectory} ${taskDir}

	    else
	        echo "${checkResult}"
	    fi
	    # return to the parent for the next task
	    cd -
    fi
done	 
