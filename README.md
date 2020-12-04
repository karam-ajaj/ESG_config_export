#  A script to export all ESG configuration for multiple vCenters

Description: This script exports all the edges configurations and place the backup on a local location

Backup location: C:\Backups\NSX_ESG\backup_date

Script location: C:\Script\Export_NSX_ESG_configuration.ps1

# Windows Task:
* name: esg-backup
* action: powershell -ExecutionPolicy Unrestricted -File  C:\Script\Export_NSX_ESG_configuration.ps1
* frequency: each Saturday on 21:15
