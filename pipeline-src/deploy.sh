#!/bin/bash

resourceGroup="$CONFIG_RESOURCEGROUP"
storageAccount="$CONFIG_STORAGEACCOUNT"
siteSubDir="$CONFIG_SITESUBDIR"

storageKey=$(az storage account keys list -g "$resourceGroup" -n "$storageAccount" | jq -r '.[0].value')
if [ -z "$storageKey" ]; then
    echo "Failed to retrieve storage account key."
    exit 1
fi

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

cat 'log.txt'
exit $cloneResult
