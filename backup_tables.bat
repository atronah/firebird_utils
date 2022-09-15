@echo off

SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

rem Example of using:
rem $ backup_tables.bat localhost:my_db "TABLE1;TABLE2"
rem backups all data of tables TABLE1 and TABLE2 from localhost:my_db
rem and split result scripts into parts of 10000 insert statements

set isql_util=isql
set zip_util=7z

set db_connect=%1
set db_user=CHEA
set db_pass=PDNTP
set BUNCH_SIZE=%3
set TABLE_LIST=%~2


rem Current date and time into variables
rem `year`, `month`, `day`, `hour`, `min` and `secs`
set year=%date:~-4%
set month=%date:~3,2%
if "%month:~0,1%" == " " set month=0%month:~1,1%
set day=%date:~0,2%
if "%day:~0,1%" == " " set day=0%day:~1,1%
set datetimef=%year%%month%%day%_%hour%%min%%secs%
set hour=%time:~0,2%
if "%hour:~0,1%" == " " set hour=0%hour:~1,1%
set min=%time:~3,2%
if "%min:~0,1%" == " " set min=0%min:~1,1%
set secs=%time:~6,2%
if "%secs:~0,1%" == " " set secs=0%secs:~1,1%

set result_filename=%year%%month%%day%_%hour%%min%%secs%.7z


for %%T in (%TABLE_LIST%) do (
    echo creating SQL-script to backup %%T

    echo SET HEADING OFF; > TEMP_SCRIPT.sql
    echo set term # ; >> TEMP_SCRIPT.sql
    echo execute block >> TEMP_SCRIPT.sql
    echo returns (stmt varchar(4096^)^) >> TEMP_SCRIPT.sql
    echo as >> TEMP_SCRIPT.sql
    echo declare records_count bigint; >> TEMP_SCRIPT.sql
    echo declare start_row bigint; >> TEMP_SCRIPT.sql
    echo declare end_row bigint; >> TEMP_SCRIPT.sql
    echo begin >> TEMP_SCRIPT.sql
    echo    records_count = (select count(*^) from %%T^); >> TEMP_SCRIPT.sql
    echo    start_row = 1; >> TEMP_SCRIPT.sql
    echo    while (start_row ^<= records_count^) do >> TEMP_SCRIPT.sql
    echo    begin >> TEMP_SCRIPT.sql
    echo        end_row = start_row + %BUNCH_SIZE% - 1; >> TEMP_SCRIPT.sql
    echo        stmt = 'SET HEADING OFF; select cast(statement as varchar(32000^)^)' >> TEMP_SCRIPT.sql
    echo            ^|^| ' from aux_get_insert_statement(''%%T'', null' >> TEMP_SCRIPT.sql
    echo            ^|^| ', ''REPL$ID,REPL$GRPID'', ''' ^|^| start_row ^|^| ' to ' ^|^| end_row  ^|^| '''' >> TEMP_SCRIPT.sql
    echo            ^|^| ', 1, %BUNCH_SIZE%^);'; >> TEMP_SCRIPT.sql
    echo        suspend; >> TEMP_SCRIPT.sql
    echo        start_row = start_row + %BUNCH_SIZE%; >> TEMP_SCRIPT.sql
    echo    end >> TEMP_SCRIPT.sql
    echo end# >> TEMP_SCRIPT.sql
    echo set term ; # >> TEMP_SCRIPT.sql

    SET part_number=1
    for /F "tokens=*" %%S in ('"%isql_util%" -user %db_user% -pas %db_pass% -q -i TEMP_SCRIPT.sql %db_connect%') do (
        echo executing SQL-script to backup !part_number! part of %%T into atchive !result_filename!
        echo %%S > TEMP_SUB_SCRIPT.sql
        rem python used just to strip string, remove that line if it's not installed
        "%isql_util%" -user %db_user% -pas %db_pass% -q -i TEMP_SUB_SCRIPT.sql %db_connect% ^
                | python3 -c "import sys,os; print(os.linesep.join(map(str.strip, sys.stdin.readlines())))" ^
                | %zip_util%  a -si%%T.part!part_number!.sql !result_filename!
        set /A part_number=part_number+1
    )
    echo removing SQL-scripts TEMP_SCRIPT.sql and TEMP_SUB_SCRIPT.sql
    DEL TEMP_SCRIPT.sql
    DEL TEMP_SUB_SCRIPT.sql
)

