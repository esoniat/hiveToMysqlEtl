rem @echo off
rem
rem A bat file to run the shell file for a scheduled run
rem The taskDirectory (hourly,daily,weekly,etc) is specified on 
rem the command line.
rem 
rem The log will be in the taskDirectory unless there is an
rem error setting the task directory in which case it will be
rem in the working directory.
rem 
rem These only need to be changed if the code installation changes
set logFileName=etlbat.log
rem Use the cygwin path for the taskCommand
rem set taskCommand=/cygdrive/d/Analytics/hiveEtl/etlScripts/hiveToSqlEtl/runAllTasksBackground.sh
set taskCommand=/cygdrive/d/Analytics/hiveEtl/hiveToMysqlEtl/hiveToSqlEtl/runAllTasksBackground.sh
rem
if [%1]==[] goto argerror
set taskDirectory=%1
set logFileName=%taskDirectory%\scheduledBatFile.log
rem The task execution
rem for some reason this doesn't log
bash  %taskCommand% -t %taskDirectory% >>%logFileName%
goto :eof
:argerror
echo "No taskDirectory argument provided." >> %logFileName%
