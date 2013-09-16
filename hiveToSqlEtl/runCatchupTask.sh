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
etlConfigFileName="hiveEtlConfig"



function usage() {
    cat <<EOF
 usage:$0 options 
 Runs the etl task as defined in the task directory

 OPTIONS:
  -h Show this message
  -t Specify full path to etl task directory
  -s Day ago to start (ie 30, start 30 days ago)
  -e Optional Day ago to end  (default 0)
  -c Optional hive config file name (default hiveEtlConfig)
EOF
}

#
# Main
#
dayAgoEnd=0
etlConfigFileName="hiveEtlConfig"
while getopts "ht:s::e::c:" opt; do
    case $opt  in
	t)
	    taskDir=${OPTARG}
	    ;;
	s)
	    dayAgoStart=${OPTARG}
	    ;;
	e)
	    dayAgoEnd=${OPTARG}
	    ;;
    c)
        etlConfigFileName=${OPTARG}
        ;;

	?)
        usage
	    exit 1
	    ;;

    esac
done
# We parsed some but was it enough
if [[ -z ${taskDir} || -z ${dayAgoStart} ]] ; then
    echo "Missing required argument"
    usage
    exit 1
fi
if [[ ${dayAgoEnd} -gt ${dayAgoStart}  ]] ; then
    echo "Start ${dayAgoStart} is greater than end ${dayAgoEnd}"
    echo "Start is the number of days ago to start processsing"
    echo "End is the number of days ago to end processing"
    exit 1
fi
#
# get to the left overs (not that we need them now)
shift $((OPTIND -1))
#
startDate=$(eval "date --date \"${dayAgoStart} day ago\" +%Y%m%d")
endDate=$(eval "date --date \"${dayAgoEnd} day ago\" +%Y%m%d")
echo "$(date) Running cachup task in ${taskDir} from ${startDate} to ${endDate} using config ${etlConfigFileName}"


# So a hack for detecting test tasks has led to this hack.
# "/cygdrive/d/Analytics/hiveEtl/hiveToMysqlEtlTasks/catchup"
allTaskDirectory=${taskDir%/*}
taskDir=${taskDir##*/}
if [ ! -d ${allTaskDirectory}/${taskDir} ] ; then
    echo "Could not find directory ${allTaskDirectory}/${taskDir}"
    echo "Catchup directory contains:"
    ls -l ${allTaskDirectory}
    exit 1
fi
cd ${allTaskDirectory}/${taskDir} 
let dayAgoToRun=${dayAgoStart}
while [[ ${dayAgoToRun} -ge ${dayAgoEnd} ]] ; do
    dayToRunCmd="date --date \"${dayAgoToRun} day ago\" +%Y%m%d"
    let dayAgoToRun--
    dayToRunString=$(eval ${dayToRunCmd})
    echo "$(date)  mode running tasks ${taskDir} for ${dayToRunString} "
    ${scriptDir}/runTask.sh ${allTaskDirectory} ${taskDir} ${etlConfigFileName} ${dayToRunString}
done 

echo "$(date) task in ${taskDir} complete"
