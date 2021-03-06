#!/bin/bash
# 
# This script will go through all of the directories in the
# task directory.  Any directory containing a hiveEtlConfig file 
# will be considered a task and using the hiveEtlConfig the
# files in that directory as specified in the hiveEtlConfig
# will be used to perform a hive to mysql ETL.
#
scriptDir=$(realpath ${0%/*})
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
unset debugMode
if [[ ${allTaskDir} == *testTaskDirectory* ]] ; then
    echo "testTaskDirectory entering debug mode" >> ${scheduledRunLog}
    debugMode="true"
fi

echo "$(date) Running tasks found in $PWD" >> ${scheduledRunLog}
for taskDir in * ; do
    # Quitly ignore files
    if [[ ! -d ${taskDir} ]] ; then
	continue;
    fi
    # Inform about dirs that do not have config files.
    if [[ ! -f $taskDir/${etlConfigFileName} ]] ; then
	echo "$(date) Skiping ${taskDir}. No ${etlConfigFileName} found" >> ${scheduledRunLog}
    else

	cd ${taskDir} >> ${scheduledRunLog}
        if [[ ! -z ${debugMode} ]] ; then
            echo "$(date) debug mode running tasks ${taskDir} sequentially" >> ${scheduledRunLog}
            ${scriptDir}/runTask.sh ${allTasksDirectory} ${taskDir} ${etlConfigFileName} >> ${taskLogFileName} 2>&1
        else
            echo "$(date) starting task ${taskDir} in background" >> ${scheduledRunLog}
            ${scriptDir}/runTask.sh ${allTasksDirectory} ${taskDir} ${etlConfigFileName}>> ${taskLogFileName} 2>&1 &
        fi
        # don't fire them all of at once
	if [[ ! -z ${debugMode} ]] ; then
            sleep 60
	fi
	# return to the parent for the next task
	cd - > /dev/null
        echo "$(date) task ${taskDir} started" >> ${scheduledRunLog}
    fi
done	 
echo "$(date) All tasks found in $PWD have been processed " >> ${scheduledRunLog}
