<#
    .DESCRIPTION
        List of common functions to deploy Azure resources 

    .NOTES
        LASTEDIT: Jan 27, 2020
#>

$ErrorActionPreference = "Stop"

if (!(Get-InstalledModule -Name Az)){
	Write-Host "Installing Az module"
    Install-Module -Name Az -Force -AllowClobber
}

if (!(Get-Module -Name Az)){
	Write-Host "Importing Az module"
    Import-Module -Name Az
}

function Create-ResourceGroup{
    Param (
        [Parameter(Mandatory=$True)][string]$resourceGroupName,
        [string]$location
    )
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -Location $location -ErrorAction SilentlyContinue
    if ($resourceGroup -and $resourceGroup.ResourceGroupName -eq $resourceGroupName) 
    {
	     Write-Warning "Resource group $resourceGroupName already exists!"
    }
    else
    {
	    Write-Host "Creating resourcegroup $resourceGroupName";
	    New-AzResourceGroup -Name $resourceGroupName -Location $location
    }
}

function Create-Database{
    Param (
        [Parameter(Mandatory=$True)][string]$resourceGroupName,
        [Parameter(Mandatory=$True)][string]$location,
        [Parameter(Mandatory=$True)][string]$sqlAdminUsername,
        [Parameter(Mandatory=$True)][string]$sqlAdminPassword,        
        [Parameter(Mandatory=$True)][hashtable]$firewallRules
    )
    $serverName = "$resourceGroupName-sqlserver";
    $databaseName = "$resourceGroupName-sqldb";

	$server = Get-AzSqlServer -ResourceGroupName $resourceGroupName -ServerName $serverName -ErrorAction SilentlyContinue
    if ($server -and $server.serverName -eq $serverName) 
    {
	    Write-Host "SQL Server $serverName already exists";
    }
    else
    {
	    Write-Host "Creating SQL Server $serverName";
	    # Create a server with a system wide unique server name
	    $server = New-AzSqlServer -ResourceGroupName $resourceGroupName `
		    -ServerName $serverName `
		    -Location $location `
		    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqlAdminUsername, $(ConvertTo-SecureString -String $sqlAdminPassword -AsPlainText -Force))

	    Write-Host "Creating server firewall rules";
        foreach ($key in $firewallRules.Keys){
            $ipAddress = $firewallRules["$key"]
	        New-AzSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $serverName -FirewallRuleName "$key" -StartIpAddress $ipAddress -EndIpAddress $ipAddress
        }
    }

    $database = Get-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName -DatabaseName $databaseName -ErrorAction SilentlyContinue
    if ($database -and $database.databaseName -eq $databaseName) 
    {
	    Write-Warning "Database $databaseName already exists";
    }
    else
    {
	    Write-Host "Creating database $databaseName";
	    New-AzSqlDatabase  -ResourceGroupName $resourceGroupName `
		    -ServerName $serverName `
            -DatabaseName $databaseName `
            -RequestedServiceObjectiveName "S0" `
            -SampleName "AdventureWorksLT"
    }
}

function Create-ServicePlan{
    Param (
        [Parameter(Mandatory=$True)][string]$resourceGroupName,
        [Parameter(Mandatory=$True)][string]$location,
		[Parameter(Mandatory=$True)][string]$appServicePlanName,
        [string]$tier = "Basic",
		[int]$numWorkers = 3,
		[string]$workerSize = "Medium"
    )

    $appServicePlan = Get-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName -ErrorAction SilentlyContinue
    if ($appServicePlan -and $appServicePlan.Name -eq $appServicePlanName){
        Write-Warning "Service plan $appServicePlanName already exists!"
    }
    else{
        Write-Host "Creating serviceplan $appServicePlanName";
        New-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName -Location $location -Tier $tier -NumberofWorkers $numWorkers -WorkerSize $workerSize
    }
}

function Create-StorageAccount{
    param (
	    [Parameter(Mandatory=$True)][string]$resourceGroupName,
        [Parameter(Mandatory=$True)][string]$storageAccountName,
        [Parameter(Mandatory=$True)][string]$location
    )
  
    if ($storageAccountName.Length -ge 24){
        $storageAccountName = $storageAccountName.Substring(0,24)  
    }

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -ErrorAction SilentlyContinue
    if ($storageAccount -and $storageAccount.StorageAccountName -eq $storageAccountName) 
    {
        Write-Warning "Storage account $storageAccountName already exists";	
    }
    else
    {
        Write-Host "Creating Storage account $storageAccountName";
        $AzureStorageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -Location $location -SkuName "Standard_GRS"
            
        Write-Host "Creating json storage container"
        New-AzStorageContainer -Name "jsoncontainer" -Context ($AzureStorageAccount.Context) -Permission Off | Out-Null	                                   
    }    	
}

function Set-AzureConnection {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$tenantID,
        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]$accountUserName,
        [parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [String]$accountPassword
    )
    
    if (Get-AzContext){
        Disconnect-AzAccount -Username "$accountUserName" | Out-Null
    }

    [SecureString] $PasswordSecure = $accountPassword | ConvertTo-SecureString -AsPlainText -Force
    $AzureUserCredential = New-Object System.Management.Automation.PSCredential($accountUserName, $PasswordSecure)
    Connect-AzAccount -Credential $AzureUserCredential -TenantId $tenantID | Out-Null    
}