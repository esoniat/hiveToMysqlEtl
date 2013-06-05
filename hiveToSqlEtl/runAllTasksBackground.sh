#!/bin/bash
# 
# This script will go through all of the directories in the
# task directory.  Any directory containing a hiveEtlConfig file 
# will be considered a task and using the hiveEtlConfig the
# files in that directory as specified in the hiveEtlConfig
# will be used to perform a hive to mysql ETL.
#
scriptDir=${0%/*}
taskLogFileName="task.log"
scheduledRunLog="runAll.log"
etlConfigFileName="hiveEtlConfig"
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
	        usage >> ${scheduledRunLog}
	        exit 1
	        ;;

    esac
done
#
# get to the left overs (not that we need them now
shift $((OPTIND -1))
if [[ -z ${allTasksDirectory} ]] ; then
    echo "$(date) The task directory must be specified"
    usage  >> ${scheduledRunLog}
    exit 1
fi
cd ${allTasksDirectory} >> ${scheduledRunLog}
echo "$(date) Running tasks found in $PWD" >> ${scheduledRunLog}
for taskDir in * ; do
    # Quitly ignore files
    if [[ ! -d ${taskDir} ]] ; then
	    continue;
    fi
    # Inform about dirs that do not have config files.
    if [[ ! -f $taskDir/${etlConfigFileName} ]] ; then
	    echo "Skiping ${taskDir}. No ${etlConfigFileName} found"
    else
        echo "$(date) starting task ${taskDir} in background" >> ${scheduledRunLog}
	    cd ${taskDir} >> ${scheduledRunLog}
        ${scriptDir}/runTask.sh ${allTasksDirectory} ${taskDir} ${etlConfigFileName}>> ${taskLogFileName}&
        # don't fire them all of at once
        sleep 10
	    # return to the parent for the next task
	    cd - > /dev/null
        echo "$(date) task ${taskDir} started" >> ${scheduledRunLog}
    fi
done	 
echo "$(date) All tasks found in $PWD have been processed " >> ${scheduledRunLog}
