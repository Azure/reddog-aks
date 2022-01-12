rm ./outputs/*
rm ./logs/*
rm *.pfx

az ad sp list --show-mine -o json --query "[?contains(displayName, 'reddog')]" | jq -r '.[] | .appId' | xargs -P 4 -n 12 -I % az ad sp delete --id %