# (Unmanaged) K8S on the cloud

Trying to deploy a K8s cluster on Azure and AWS with Ansible, without
using the CSP-specific managed offering.

```
RGNAME=<some resource group name>
az group create --name $RGNAME --location 'westus2'

ssh-keygen <ssh options> -C "<username>@azure" -f <keypair>
keychain --eval <keypair>    # or use `ssh-add` directly

az deployment group create --resource-group $RGNAME --template-file infra.bicep --parameters vmname=<vmname> vmuser=<username> publickey="$(< <keypair>.pub)"
az deployment group show -g $RGNAME -n infra --query properties.outputs.sshCommand
# Show internal IPs of the workers
az deployment group show -g $RGNAME -n infra --query properties.outputs.privateIPAddress

ssh -A -i <keypair>  <username>@<output_of_show>
```

