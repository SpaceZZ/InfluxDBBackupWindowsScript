<#
author SpaceZ
version 1 07/07/2020

Script takes a periodical backup of the InfluxDB and puts it in the specified location.
It is possible to either:
1. perform incremental backup based on the external trigger (i.e. Windows Task Scheduler). Script will then request backup since last taken backup 
   (_inc appended to folder name, folder name is time in UTC since when increment is backed up). Task Scheduler needs to be configured separetely from the script.
2. perform full backup - script will then create new full backup periodically
   (_full appended to folder name, full database backup)

Script can also delete old backups. Specify the number of backups to keep existing (default 12) and it will delete all other ones. Set $isDeleteOldBackups to $true

#> 



#settings section

$PATH = "D:\InfluxDbBackups"
$Influx_PATH = "<PUT INFLUX PATH>"
$databaseName = "<DATABASE NAME>"

# Incremental Backups Enable
$isIncremental = $false

# Full Backups Enable
$isFull = $true

# Delete old backups
$isDeleteOldBackups = $true
$numberOfBackupsToLeave = 12


$cmd = "influxd backup -portable -database " + $databaseName + " -host 127.0.0.1:8088 "

#date pattern for the ISO 8601
$DatePattern = "yyyyMMddTHHmmssZ"



#script

# converts from datetime to IS8601 format
function ConvertToUTCTime([datetime] $dt)
{
    $utc = $dt.ToUniversalTime().ToString("s")+"Z"
    
    return $utc

}

# converts from ISO 8601 to datetime
function ConvertFromUTCtoDateTime([string] $s)
{
    $parsed_date = [datetime]::ParseExact($s,$DatePattern,$null) 
    
    return $parsed_date
}

#gets the now date for folder creation
function GetNowDateUTC
{
    $date = [DateTime]::UtcNow.ToString("s") + "Z"
    
    $date = $date -replace "-","" -replace ":",""
    
    return $date
}

function CreateDirNamefromUTC([string] $s)
{
    $s = $s -replace "-","" -replace ":",""
    return $s
}

function CreateFullBackup
{
    Set-Location $Influx_PATH
    
    $now = GetNowDateUTC
    
    $full_cmd = $cmd + $PATH + "\" + $now + "_full"
    
    iex $full_cmd  
}

function CreateIncrementalBackup
{
    #get latest write manifest file
    
    $file = Get-ChildItem -Path $PATH -Filter *.manifest* -Recurse -ErrorAction SilentlyContinue -Force |sort LastWriteTime |select -Last 1
    
    $date = [System.IO.Path]::GetFileNameWithoutExtension($file)
    
    $since = ConvertFromUTCtoDateTime($date)
    
    $since = ConvertToUTCTime($since)
    
    $since_dir_name = CreateDirNamefromUTC($since)
    
    Set-Location $Influx_PATH
    
    $full_cmd = $cmd + "-since " + $since + " " + $PATH + "\" + $since_dir_name + "_inc"
    
    iex $full_cmd

}
#function checks if there is at least one full backup
function CheckIfFullBackupExists
{
    $full_backups = dir -Directory $PATH -Filter *_full*

    if($full_backups -ne $null)
    {
        return $true
    }
    else
    {
        return $false
    }
}


if($isIncremental)
{
    if(!(Test-Path $PATH))
    {
      #create full backup if no path was found - means there is no backup
      
      CreateFullBackup     
    }
    else
    {
      #create incremental backup // check last manifest file
      
      $file = Get-ChildItem -Path $PATH -Filter *.manifest* -Recurse -ErrorAction SilentlyContinue -Force |sort LastWriteTime |select -Last 1

      if(($file -ne $null) -and (CheckIfFullBackupExists))
      {
        #create incremental if at least one manifest file was found and full backup already exists
        
        CreateIncrementalBackup
      }
      else
      {
        #no manifest, you need to start with full
        
        CreateFullBackup
      }
    } 
}

if($isFull)
{
    #at every run create full backup
    
    CreateFullBackup
}

if($isDeleteOldBackups)
{
    #delete old backups, leave only number specified
    
    $existingBackups = dir -Directory $PATH
    
    $numberOfExistingBackups = $existingBackups | Measure-Object
    
    if($numberOfExistingBackups.Count -gt $numberOfBackupsToLeave)
    {
        $diff = $numberOfExistingBackups.Count - $numberOfBackupsToLeave
        
        $backupsToDelete = dir -Directory $PATH | sort LastWriteTime | select -First $diff
        
        Set-Location $PATH

        foreach ($backup in $backupsToDelete)
        {
            Remove-Item -Recurse -Force $backup
        }
        
        if(!(CheckIfFullBackupExists))
        {
            CreateFullBackup
        }
    }
}


