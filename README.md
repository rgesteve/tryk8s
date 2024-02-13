# (Unmanaged) K8S on the cloud

Trying to deploy a K8s cluster on Azure and AWS with Ansible, without
using the CSP-specific managed offering.

```
RGNAME=<some resource group name>
az group create --name $RGNAME --location 'westus2'

ssh-keygen <ssh options> -C "<username>@azure" -f <keypair>
keychain --eval <keypair>    # or use `ssh-add` directly

az deployment group create --resource-group $RGNAME --template-file infra.bicep --parameters vmname=<vmname> vmuser=<username> publickey="$(< <keypair>.pub)"
```

You can check the details to log on to the jumpbox/controller:
```
az deployment group show -g $RGNAME -n infra --query properties.outputs.sshCommand
```

As well as list the internal IPs of the workers (right now there's only one worker)
```
az deployment group show -g $RGNAME -n infra --query properties.outputs.privateIPAddress
```

Now you can log on to the jumpbox using the keypair created above:
```
ssh -A -i <keypair>  <username>@<output_of_show>
```
From there you can log on to any of the workers using their private IP:
```
ssh <private_ip_of_worker>
```

You can get a list of the deployed VMs, along with their private IPs like so:
```
az vm list -g $RGNAME -d --query "[?tags.applicationRole=='controller'].{name: name, pip: privateIps}" -o tsv
```

## KNOWN ISSUES

* If you get a 'core quota exceeded' error, balance the `controllercount` parameter with the VM size (in `commonProfile.hardwareProfile`)

## TODO

* Use appropriate hostnames
* Add ansible-based configuration to provision k8s packages

