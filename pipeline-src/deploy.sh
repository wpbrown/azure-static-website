#!/bin/bash

resourceGroup="$CONFIG_RESOURCEGROUP"
storageAccount="$CONFIG_STORAGEACCOUNT"
siteSubDir="$CONFIG_SITESUBDIR"

# Acquire storage keys
storageKey=$(az storage account keys list -g "$resourceGroup" -n "$storageAccount" | jq -r '.[0].value')
if [ -z "$storageKey" ]; then
    echo "Failed to retrieve storage account key."
    exit 1
fi

# Enable firewall access
myIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
if [ -z "$myIP" ]; then
    echo "Failed to retrieve my public ip."
    exit 2
fi

az storage account network-rule add --account-name "$storageAccount" --ip-address "$myIP"
sleep 1

# Validate firewall access
for i in {1..5}; do 
    props=$(az storage blob service-properties show --account-name $storageAccount --account-key "$storageKey")
    if [ -n "$props" ]; then 
        break;
    elif [ $i == 5 ]; then
        echo "Failed to validate firewall access to storage account."
        exit 3
    fi
    sleep 5; 
done
echo "Network access to account verified."

# Run the sync process
configFile=\
"[azure]
type = azureblob
account = $storageAccount
key = $storageKey
endpoint =
"

rm -f 'log.txt'
rclone sync public "azure:\$web$siteSubDir" --checksum --fast-list --log-file 'log.txt' --log-level INFO \
    --config <(echo "$configFile")
cloneResult=$?

# Revoke firewall access
az storage account network-rule remove --account-name "$storageAccount" --ip-address "$myIP"

# Handle results
cat 'log.txt'
exit $cloneResult

