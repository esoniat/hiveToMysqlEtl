@echo off
rem
rem 
rem These only need to be changed if the code installation changes
set logFileName=etlbat.log
rem Use the cygwin path for the taskCommand
set taskCommand=/cygdrive/d/Analytics/hiveEtl/hiveToMysqlEtl/hiveToSqlEtl/sshCheck.sh
rem
rem log to  the pwd unless they give us a working directory
set logFileName=sshCheck.bat.log
if [%1]==[] goto argerror
set workingDirectory=%1
set logFileName=%workingDirectory%\sshCheck.bat.log
rem The task execution
rem for some reason this doesn't log
bash  %taskCommand% -t %workingDirectory%  >>%logFileName%
goto :eof
:argerror
echo "No working directory argument provided." >> %logFileName%
