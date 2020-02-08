param (
    [Parameter(Mandatory=$True)][string]$resourceGroupName,	
    [Parameter(Mandatory=$True)][string]$location,
	[Parameter(Mandatory=$True)][string]$accountUserName,
    [Parameter(Mandatory=$True)][string]$accountPassword,
    [Parameter(Mandatory=$True)][string]$tenantID,
    [Parameter(Mandatory=$True)][string]$subscriptionId,
    [Parameter(Mandatory=$True)][string]$SQLadminUserName,
    [Parameter(Mandatory=$True)][string]$SQLadminPassword,
    [Parameter(Mandatory=$True)][string]$dacpacFolder
)

Import-Module "$PWD\AzureFunctions.psm1" -Force

Write-Host "Creating all resources on $resourceGroupName" -ForegroundColor red -BackgroundColor white

$ErrorActionPreference = "Stop"

if (!(Get-InstalledModule -Name Az)){
	Write-Host "Installing Az module"
    Install-Module -Name Az -Force
}

if (!(Get-Module -Name Az)){
    Import-Module -Name Az -Force
}

if (!(Get-InstalledModule -Name SqlServer)){
	Write-Host "Installing SqlServer module"
    Install-Module -Name SqlServer -Force
}

if (!(Get-Module -Name SqlServer)){
    Import-Module -Name SqlServer    
}

if (Get-AzContext){
    Clear-AzContext -Force
}


if ($accountUserName -and $accountPassword -and $tenantID -and $subscriptionId)
{
    Set-AzureConnection -tenantID $tenantID -accountUserName $accountUserName -accountPassword $accountPassword
    Set-AzContext -SubscriptionId $subscriptionId | Out-Null

	$firewallRules = @{"Allow Azure Resources" = "0.0.0.0" }
    Create-ResourceGroup -resourceGroupName $resourceGroupName -location $location
    Create-Database -resourceGroupName $resourceGroupName -location $location -sqlAdminUsername $SQLadminUserName -sqlAdminPassword $SQLadminPassword -firewallRules $firewallRules
    
    $storageAccountName = "{0}storage" -f ($resourceGroupName -replace '\W')
    Create-StorageAccount -resourceGroupName $resourceGroupName -location $location -storageAccountName $storageAccountName

    $appServicePlanName = "$resourceGroupName-appserviceplan".ToLower()    
	Create-ServicePlan -resourceGroupName $resourceGroupName -appServicePlanName $appServicePlanName -location $location
}
else{
    throw "Account user name, password, tenant id, and subscription id are required."
}

Write-Host "Deploying database on $resourceGroupName"

Deploy-Database -resourceGroupName $resourceGroupName -dacpacFolder $dacpacFolder -sqlAdminUsername $SQLadminUserName -sqlAdminPassword $SQLadminPassword

Write-Host "Resources have been created under $resourceGroupName" -ForegroundColor red -BackgroundColor white

Exit 0