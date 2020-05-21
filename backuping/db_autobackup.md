# Backuping database on unix


[db_autobackup](backuping/db_autobackup.sh) - shell-script to automatic making backup of database
with checking log of restoring for errors.

That script has been developed to prevent changing its body for different evnviroments
(it allow just replace script to update it).

All needed settings you can pass by script call [arguments](#arguments).


## Arguments

(all arguments except `-m` и `-n` are described with default values,
but arguments `-m` и `-n` are disabled by default)

- `-g /opt/firebird/gbak` - path to gbak tool of DBMS
- `-h 127.0.0.1/3050` - address and port of DBMS instance
- `-d box_med` - database alias
- `-u CHEA` - database user
- `-p PDNTP` - password of database user
- `-o /var/db/backups/auto` - target directory for result (7z archive with backup and logs)
- `-w /var/db/backups/auto/tmp` - working directory for temporary storing files wit backups and logs and archive
and to permanent storing fresh restored copy of database (and logs of it).
- `-m /var/db/backups/scripts/mover.sh` - script for moving result archive with backup to another place
(if specified it will be called with single argument - full path to archive);
example: [db_autobackup_mover.sh](backuping/db_autobackup_mover.sh)
- `-n /var/db/backups/scripts/notifier.sh` - script for sending notifications about errors
(if specified it will be called with single argument - error message text from log files);
example: [db_autobackup_notifier.sh](backuping/db_autobackup_notifier.sh)


Example of runneing script `run_backup_for_db.sh`
(for puproses when you need making backup of few databases which different only by alias):

```
#! /bin/sh

scriptpath="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

rdb="/opt/RedDatabase/bin/gbak"
db_host=127.0.0.1/3050
db_user=SYSDBA
db_pswd=masterkey
outdir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
workdir="$outdir/tmp"
mover="$scriptpath/db_autobackup_mover.sh"
notifier="$scriptpath/db_autobackup_notifier.sh"

$scriptpath/db_autobackup.sh -d $1 -g "$rdb" -h $db_host -u $db_user -p $db_pswd -o "$outdir" -w "$workdir" -m "$mover" -n "$notifier"
```


## Working description

That script do follow actions sequentially:

- changes working directiory (`popd`) to directory from [argument](#arguments) `-w`
(make that directory before if it needs)
- makes backup with log
- check backuping log for errors;
if it contains errors
    - log file will be prefixed `ERROR_` and moved to outdir from argument `-o`
    - script from argument `-n` will be called with text of error from log
- makes restore of backup with log
- check backuping log for errors;
if it contains errors
    - log file will be prefixed `ERROR_` and moved to outdir from argument `-o`
    - script from argument `-n` will be called with text of error from log
- makes 7z archive which contains backup (`.fbk`), backup log `.fbk.log` and restore log `.fdb.log`
- moves archive to outdir from argument `-o` (with replacing)
- calls script from argument `-m` (if it specified) with full path of archive
- removes backup file and logs
- renames restore file and its log to `<db_alias>.fdb` and `<db_alias>.fdb.log`



