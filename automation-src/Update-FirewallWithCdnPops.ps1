Param
(
  [Parameter(Mandatory=$true)]
  [String] $accountName,
  [Parameter(Mandatory=$true)]
  [String] $resourceGroup
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$connectionName = "AzureRunAsConnection"
$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

"Logging in to Azure..."
Connect-AzureRmAccount `
    -ServicePrincipal `
    -TenantId $servicePrincipalConnection.TenantId `
    -ApplicationId $servicePrincipalConnection.ApplicationId `
    -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint > $null

# Get AzureRM Access Token
$context = Get-AzureRmContext
$tokenCache = $context.TokenCache
$cachedTokens = $tokenCache.ReadItems()
$accessToken = $cachedTokens[0].AccessToken

# Retrieve CDN POP Data
$data = Invoke-RestMethod -Method Get `
    -Uri 'https://management.azure.com/providers/Microsoft.Cdn/edgenodes?api-version=2017-10-12' `
    -Headers @{ 'Authorization' = "Bearer $accessToken" }
$regions = ($data.value | Where-Object { $_.name -eq 'Premium_Verizon' }).Properties.ipAddressGroups
"Processing Delivery Regions: $($regions | Select-Object -ExpandProperty deliveryRegion)"
$addressGroups = $regions.ipv4Addresses

# Retrieve Traffic Manager Probe IPs
$data = Invoke-RestMethod -Method Get `
    -Uri 'https://azuretrafficmanagerdata.blob.core.windows.net/probes/azure/probe-ip-ranges.json'
$addressGroups += $data.ipv4_prefixes.ip_prefix | ForEach-Object { $parts = $_.Split('/'); `
    [PSCustomObject]@{ baseIpAddress = $parts[0]; prefixLength = $parts[1] } }

# Prepare new ACLs
$invalidPrefixes = 0
$rules = $addressGroups | ForEach-Object {
    if ($_.prefixLength -eq 32) { $address = $_.baseIpAddress }
    elseif ($_.prefixLength -le 29) { $address = "$($_.baseIpAddress)/$($_.prefixLength)" }
    else { 
        Write-Warning "CDN provided invalid prefix length ($($_.prefixLength)) for storage account firewall."
        ++$invalidPrefixes
        $address = $null;
    }

    if ($address) {
        @{IPAddressOrRange=$address; Action="allow"}
    }
}

# Apply new ACLs
$newRuleCount = ($rules | Measure-Object).Count
"Apply Updates ($newRuleCount rules): $($rules | ForEach-Object {$_['IPAddressOrRange']})"
Update-AzureRmStorageAccountNetworkRuleSet -IPRule $rules -AccountName $accountName -ResourceGroupName $resourceGroup > $null

if ($invalidPrefixes) {
    Write-Error "CDN provided $invalidPrefixes invalid prefixes for storage account firewall."
}
