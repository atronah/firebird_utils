@echo off

SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set fb_root="C:\Program Files\Firebird\Firebird_3_0"
set db_connect="127.0.0.1:box_med"
set db_user=SYSDBA
set db_password=masterkey
set gstat_log="D:\Infodata\gstat.log"
set sql_folder="D:\Infodata\"

REM Current date and time
set hour=%time:~0,2%
if "%hour:~0,1%" == " " set hour=0%hour:~1,1%
set min=%time:~3,2%
if "%min:~0,1%" == " " set min=0%min:~1,1%
set secs=%time:~6,2%
if "%secs:~0,1%" == " " set secs=0%secs:~1,1%
set year=%date:~-4%
set month=%date:~3,2%
if "%month:~0,1%" == " " set month=0%month:~1,1%
set day=%date:~0,2%
if "%day:~0,1%" == " " set day=0%day:~1,1%
set datetimef=%year%%month%%day%_%hour%%min%%secs%

echo "========> connections at %year%-%month%-%day% %hour%:%min%:%secs% for %db_connect% <========" >> %gstat_log%
REM example of count_connections.sql
REM    select
REM        count(*) as all_conections
REM        , count(iif(mon$timestamp < cast(dateadd(-1 day to current_date) || ' 22:00:00' as timestamp)
REM                , mon$attachment_id
REM               , null)
REM        ) as old_connections
REM    from mon$attachments;
%fb_root%\isql -user %db_user% -pas %db_password% -i %sql_folder%\count_connections.sql %db_connect% >> %gstat_log%


REM echo "========> detach all and execute special script %year%-%month%-%day% %hour%:%min%:%secs% <========" >> %gstat_log%
REM %fb_root%\isql -user %db_user% -pas %db_password% -i %sql_folder%\detach_all.sql %db_connect%
REM %fb_root%\isql -user %db_user% -pas %db_password% -i %sql_folder%\after_detach_all.sql %db_connect%

echo "========> detaching old connections %year%-%month%-%day% %hour%:%min%:%secs% for %db_connect% <========" >> %gstat_log%
REM example of detach_old_connections.sql
REM     delete from mon$attachments where mon$timestamp < cast(dateadd(-1 day to current_date) || ' 22:00:00' as timestamp); commit;
%fb_root%\isql -user %db_user% -pas %db_password% -i %sql_folder%\detach_old_connections.sql %db_connect%

echo "========> connections after detaching at %year%-%month%-%day% %hour%:%min%:%secs% for %db_connect% <========" >> %gstat_log%
%fb_root%\isql -user %db_user% -pas %db_password% -i %sql_folder%\count_connections.sql %db_connect% >> %gstat_log%

echo "========> start sweeping at %year%-%month%-%day% %hour%:%min%:%secs% for %db_connect% <========" >> %gstat_log%
%fb_root%\gfix -user %db_user% -pas %db_password% -sweep %db_connect%

echo "========> gstat after %year%-%month%-%day% %hour%:%min%:%secs% for %db_connect% <========" >> %gstat_log%
%fb_root%\gstat -header %db_connect% >> %gstat_log%

