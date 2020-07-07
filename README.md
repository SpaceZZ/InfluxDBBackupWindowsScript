# InfluxDBBackupWindowsScript
Powershell script to backup InfluxDB

Script takes a periodical backup of the InfluxDB and puts it in the specified location.
It is possible to either:
1. perform incremental backup based on the external trigger (i.e. Windows Task Scheduler). Script will then request backup since last taken backup 
   (_inc appended to folder name, folder name is time in UTC since when increment is backed up). Task Scheduler needs to be configured separetely from the script.
2. perform full backup - script will then create new full backup periodically
   (_full appended to folder name, full database backup)

Script can also delete old backups. Specify the number of backups to keep existing (default 12) and it will delete all other ones. Set $isDeleteOldBackups to $true
