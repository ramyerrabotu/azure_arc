Start-Transcript -Path C:\ArcBox\DataServicesLogonScript.log

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

$azurePassword = ConvertTo-SecureString $env:spnClientSecret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($env:spnClientID , $azurePassword)
Connect-AzAccount -Credential $psCred -TenantId $env:spnTenantId -ServicePrincipal

Write-Host "Installing Azure Data Studio Extensions"
Write-Host "`n"

$env:argument1="--install-extension"
$env:argument2="Microsoft.arc"
$env:argument3="microsoft.azuredatastudio-postgresql"

& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument2
& "C:\Program Files\Azure Data Studio\bin\azuredatastudio.cmd" $env:argument1 $env:argument3

Write-Host "Creating Azure Data Studio Desktop shortcut"
Write-Host "`n"
$TargetFile = "C:\Program Files\Azure Data Studio\azuredatastudio.exe"
$ShortcutFile = "C:\Users\$env:adminUsername\Desktop\Azure Data Studio.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

# Adding Azure Arc CLI extensions
Write-Host "Adding Azure Arc CLI extensions"
az extension add --name "connectedk8s" -y
az extension add --name "k8s-configuration" -y
az extension add --name "k8s-extension" -y

# Downloading CAPI Kubernetes cluster kubeconfig file
Write-Host "Downloading CAPI Kubernetes cluster kubeconfig file"
$sourceFile = "https://$env:stagingStorageAccountName.blob.core.windows.net/staging-capi/config.arcbox-capi-data"
$context = (Get-AzStorageAccount -ResourceGroupName $env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$env:USERNAME\.kube\config"
kubectl config rename-context arcbox-capi-data-admin@arcbox-capi-data arcbox-capi

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
azdata --version

# Deploying Azure Arc Data Controller
Write-Host "Deploying Azure Arc Data Controller"
Write-Host "`n"
Start-Process PowerShell {for (0 -lt 1) {kubectl get pod -n $env:ARC_DC_NAME; Start-Sleep 5; Clear-Host }}
azdata arc dc config init --source azure-arc-kubeadm --path ./custom
azdata arc dc config replace --path ./custom/control.json --json-values '$.spec.storage.data.className=fast'
azdata arc dc config replace --path ./custom/control.json --json-values '$.spec.storage.logs.className=fast'

azdata arc dc create --namespace $env:arcDcName --name $env:arcDcName --subscription $env:subscriptionId --resource-group $env:resourceGroup --location $env:azureLocation --connectivity-mode indirect --path ./custom
# Start-Sleep -Seconds 30

# Write-Host "Deploying SQL MI and Postgres data services"
# Write-Host "`n"
# New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force

# Workflow DatabaseDeploy
# {
#     Parallel {
#         InlineScript {
#             # Deploying Azure Arc PostgreSQL Hyperscale Server Group
#             azdata login --namespace $env:arcDcName
#             azdata arc postgres server create --name $env:POSTGRES_NAME --workers $env:POSTGRES_WORKER_NODE_COUNT --storage-class-data managed-premium --storage-class-logs managed-premium
#             azdata arc postgres endpoint list --name $env:POSTGRES_NAME
#             # Downloading demo database and restoring onto Postgres
#             $podname = "$env:POSTGRES_NAME" + "c-0"
#             #Start-Sleep -Seconds 300
#             #Write-Host "Downloading AdventureWorks.sql template for Postgres... (1/3)"
#             #kubectl exec $podname -n $env:arcDcName -c postgres -- /bin/bash -c "cd /tmp && curl -k -O https://raw.githubusercontent.com/microsoft/azure_arc/capi_integration/azure_jumpstart_arcbox/scripts/AdventureWorks.sql" 2>&1 $null
#             #Write-Host "Creating AdventureWorks database on Postgres... (2/3)"
#             #kubectl exec $podname -n $env:arcDcName -c postgres -- sudo -u postgres psql -c 'CREATE DATABASE "adventureworks";' postgres 2>&1 $null
#             #Write-Host "Restoring AdventureWorks database on Postgres. (3/3)"
#             #kubectl exec $podname -n $env:arcDcName -c postgres -- sudo -u postgres psql -d adventureworks -f /tmp/AdventureWorks.sql 2>&1 $null
#         }
#         InlineScript {
#             # Deploying Azure Arc SQL Managed Instance
#             azdata login --namespace $env:arcDcName
#             azdata arc sql mi create --name $env:mssqlmiName --storage-class-data managed-premium --storage-class-logs managed-premium
#             azdata arc sql mi list
#             # Downloading demo database and restoring onto SQL MI
#             $podname = "$env:mssqlMiName" + "-0"
#             #Start-Sleep -Seconds 300
#             #Write-Host "Downloading AdventureWorks database for MS SQL... (1/2)"
#             #kubectl exec $podname -n $env:arcDcName -c arc-sqlmi -- wget https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak -O /var/opt/mssql/data/AdventureWorks2019.bak 2>&1 $null
#             #Write-Host "Restoring AdventureWorks database for MS SQL. (2/2)"
#             #kubectl exec $podname -n $env:arcDcName -c arc-sqlmi -- /opt/mssql-tools/bin/sqlcmd -S localhost -U $env:AZDATA_USERNAME -P $env:AZDATA_PASSWORD -Q "RESTORE DATABASE AdventureWorks2019 FROM  DISK = N'/var/opt/mssql/data/AdventureWorks2019.bak' WITH MOVE 'AdventureWorks2017' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', MOVE 'AdventureWorks2017_Log' TO '/var/opt/mssql/data/AdventureWorks2019_Log.ldf'" 2>&1 $null
#         }
#     }
# }

# # DatabaseDeploy | Format-Table

# Creating Azure Data Studio settings for database connections
# Write-Host ""
# Write-Host "Creating Azure Data Studio settings for database connections"
# New-Item -Path "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\" -Name "User" -ItemType "directory" -Force
# Copy-Item -Path "C:\ArcBox\settingsTemplate.json" -Destination "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
# $settingsFile = "C:\Users\$env:adminUsername\AppData\Roaming\azuredatastudio\User\settings.json"
# azdata arc sql mi list | Tee-Object "C:\ArcBox\sql_instance_list.txt"
# azdata arc postgres endpoint list --name $env:POSTGRES_NAME | Tee-Object "C:\ArcBox\postgres_instance_endpoint.txt"
# $sqlfile = "C:\ArcBox\sql_instance_list.txt"
# $postgresfile = "C:\ArcBox\postgres_instance_endpoint.txt"

# (Get-Content $sqlfile | Select-Object -Skip 2) | Set-Content $sqlfile
# $sqlstring = Get-Content $sqlfile
# $sqlstring.Substring(0, $sqlstring.IndexOf(',')) | Set-Content $sqlfile
# $sql = Get-Content $sqlfile

# (Get-Content $postgresfile | Select-Object -Index 8) | Set-Content $postgresfile
# $pgstring = Get-Content $postgresfile
# $pgstring.Substring($pgstring.IndexOf('@')+1, $pgstring.LastIndexOf(':')-$pgstring.IndexOf('@')-1) | Set-Content $postgresfile
# $pg = Get-Content $postgresfile

# (Get-Content -Path $settingsFile) -replace 'arc_sql_mi',$sql | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'sa_username',$env:AZDATA_USERNAME | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'sa_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'false','true' | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'arc_postgres',$pg | Set-Content -Path $settingsFile
# (Get-Content -Path $settingsFile) -replace 'ps_password',$env:AZDATA_PASSWORD | Set-Content -Path $settingsFile

# # Cleaning garbage
# Remove-Item "C:\ArcBox\sql_instance_list.txt" -Force
# Remove-Item "C:\ArcBox\postgres_instance_endpoint.txt" -Force

# Downloading Rancher K3s kubeconfig file
Write-Host "Downloading Rancher K3s kubeconfig file"
$sourceFile = "https://$env:stagingStorageAccountName.blob.core.windows.net/staging-k3s/config"
$context = (Get-AzStorageAccount -ResourceGroupName $env:resourceGroup).Context
$sas = New-AzStorageAccountSASToken -Context $context -Service Blob -ResourceType Object -Permission racwdlup
$sourceFile = $sourceFile + $sas
azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "C:\Users\$env:USERNAME\.kube\config-k3s"

# Merging kubeconfig files from CAPI and Rancher K3s
Write-Host "Merging kubeconfig files from AKS and Rancher K3s"
Copy-Item -Path "C:\Users\$env:USERNAME\.kube\config" -Destination "C:\Users\$env:USERNAME\.kube\config.backup"
$env:KUBECONFIG="C:\Users\$env:USERNAME\.kube\config;C:\Users\$env:USERNAME\.kube\config-k3s"
kubectl config view  --raw > C:\users\$env:USERNAME\.kube\config_tmp
kubectl config get-clusters --kubeconfig=C:\users\$env:USERNAME\.kube\config_tmp
Remove-Item C:\users\$env:USERNAME\.kube\config
Remove-Item C:\users\$env:USERNAME\.kube\config-k3s
Move-Item C:\users\$env:USERNAME\.kube\config_tmp C:\users\$env:USERNAME\.kube\config
$env:KUBECONFIG="C:\users\$env:USERNAME\.kube\config"
kubectx "arcbox-k3s"

Write-Host "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
az connectedk8s connect --name "ArcBox-CAPI-Data" --resource-group $env:resourceGroup --location $env:azureLocation --tags 'Project=jumpstart_arcbox'
Start-Sleep -Seconds 10

Write-Host "Create Azure Monitor for containers Kubernetes extension instance"
az k8s-extension create --name "azuremonitor-containers" --cluster-name "ArcBox-CAPI-Data" --resource-group $CAPI_WORKLOAD_CLUSTER_NAME --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers

Write-Host "Create Azure Defender Kubernetes extension instance"
az k8s-extension create --name "azure-defender" --cluster-name "ArcBox-CAPI-Data" --resource-group $CAPI_WORKLOAD_CLUSTER_NAME --cluster-type connectedClusters --extension-type Microsoft.AzureDefender.Kubernetes

Write-Host ""
az -v

# Starting Azure Data Studio
#Start-Process -FilePath "C:\Program Files\Azure Data Studio\azuredatastudio.exe" -WindowStyle Maximized
#Stop-Process -Name powershell -Force

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "DataServicesLogonScript" -Confirm:$false
