#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

resourceGroup="$CONFIG_RESOURCEGROUP"
cdnEndpoint="$CONFIG_CDNENDPOINT"
cdnProfile="$CONFIG_CDNPROFILE"

set -o pipefail
$DIR/purge_paths.py 'log.txt' | xargs -r -t az cdn endpoint purge -g "$resourceGroup" -n "$cdnEndpoint" \
    --profile-name "$cdnProfile" --content-paths
