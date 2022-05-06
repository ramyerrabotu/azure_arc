#!/bin/bash
windowsAdminUsername=${1}
resourceGroupName=${2}
flavor=${3}
secret=${4}

# Zip all the logs files
plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g $resourceGroupName  -n ArcBox-Client --query publicIps -o tsv)  -pw  "$secret" -batch '7z a c:\ArcBox\logs\LogsBundle.zip c:\ArcBox\logs\*.log'
# Get zip file
sshpass -p "$secret" scp -o 'StrictHostKeyChecking no' -P 2204 -T $windowsAdminUsername@$(az vm show -d -g $resourceGroupName -n ArcBox-Client --query publicIps -o tsv):'c:\ArcBox\logs\LogsBundle.zip' '.'  || echo "LogsBundle.zip not able to be downloaded"

# depending on the flavor, download individual logs
sshpass -p "$secret" scp -o 'StrictHostKeyChecking no' -P 2204 -T $windowsAdminUsername@$(az vm show -d -g $resourceGroupName -n ArcBox-Client --query publicIps -o tsv):'..\..\ArcBox\Logs\Bootstrap.log' '.'  || echo "Bootstrap.log not able to be downloaded"
if [ $flavor == 'Full' ] || [ $flavor == 'ITPro' ]; then
  sshpass -p "$secret" scp -o 'StrictHostKeyChecking no' -P 2204 -T $windowsAdminUsername@$(az vm show -d -g $resourceGroupName -n ArcBox-Client --query publicIps -o tsv):'..\..\ArcBox\Logs\ArcServersLogonScript.log' '.' || echo "ArcServersLogonScript.log not able to be downloaded"
fi
if [ $flavor == 'Full' ]; then
  sshpass -p "$secret" scp -o 'StrictHostKeyChecking no' -P 2204 -T $windowsAdminUsername@$(az vm show -d -g $resourceGroupName -n ArcBox-Client --query publicIps -o tsv):'..\..\ArcBox\Logs\DataServicesLogonScript.log' '.' || echo "DataServicesLogonScript.log not able to be downloaded"
fi 
if [ $flavor == 'Full' ] || [ $flavor == 'DevOps' ]; then
sshpass -p "$secret" scp -o 'StrictHostKeyChecking no' -P 2204 -T $windowsAdminUsername@$(az vm show -d -g $resourceGroupName -n ArcBox-Client --query publicIps -o tsv):'..\..\ArcBox\Logs\DevOpsLogonScript.log' '.' || echo "DevOpsLogonScript.log not able to be downloaded"
sshpass -p "$secret" scp -o 'StrictHostKeyChecking no' -P 2204 -T $windowsAdminUsername@$(az vm show -d -g $resourceGroupName -n ArcBox-Client --query publicIps -o tsv):'..\..\ArcBox\Logs\installCAPI.log' '.' || echo "installCAPI.log not able to be downloaded"
sshpass -p "$secret" scp -o 'StrictHostKeyChecking no' -P 2204 -T $windowsAdminUsername@$(az vm show -d -g $resourceGroupName -n ArcBox-Client --query publicIps -o tsv):'..\..\ArcBox\Logs\installK3s.log' '.' || echo "installK3s.log not able to be downloaded"
fi           
sshpass -p "$secret" scp -o 'StrictHostKeyChecking no' -P 2204 -T $windowsAdminUsername@$(az vm show -d -g $resourceGroupName -n ArcBox-Client --query publicIps -o tsv):'..\..\ArcBox\Logs\MonitorWorkbookLogonScript.log' '.' || echo "MonitorWorkbookLogonScript.log not able to be downloaded"