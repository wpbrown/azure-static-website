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
$addressGroups = ($data.value | ? { $_.name -eq 'Premium_Verizon' }).Properties.ipAddressGroups

# Prepare new ACLs
"Processing Delivery Regions: $($addressGroups | select -ExpandProperty deliveryRegion)"
$rules = $addressGroups.ipv4Addresses | % {
    if ($_.prefixLength -eq 32) { $address = $_.baseIpAddress }
    elseif ($_.prefixLength -le 29) { $address = "$($_.baseIpAddress)/$($_.prefixLength)" }
    else { 
        Write-Error "CDN provided invalid CIDR for storage account firewall."
        $address = $null;
    }

    if ($address) {
        @{IPAddressOrRange=$address; Action="allow"}
    }
}

# Apply new ACLs
"Apply Updates: $($rules | % {$_['IPAddressOrRange']})"
Update-AzureRmStorageAccountNetworkRuleSet -IPRule $rules -AccountName $accountName -ResourceGroupName $resourceGroup > $null
