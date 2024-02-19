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

A better way is to generate an ssh config file from the deployed cluster, which you can do with
```
./setup_env.sh  # Installs dependencies
AZURE_SUBSCRIPTION_ID="$(az account list | jq '.[0].id')" ./gen_server_files.py
```
which creates a file "ssh_config" that you can use like:
```
ssh -F ssh_config controller
ssh -F ssh_config <any_worker>
```
Note that the workers don't expose public IPs, so the controller is configured as a jumpbox.  Moreover, forwarding (`-A`) is enabled when you log on to the controller so that you can also log on any of the workers from there.

For a quick test, you can run the following (note that `ansible` is installed with the virtual environment
```
ansible-playbook -i inventory.ini test_pb.yml
```

If you get errors about man-in-the-middle attacks, you may be using an outdated key, try issuing
```
ssh-keygen -f "~/.ssh/known_hosts" -R <problematic_ip>
```

## KNOWN ISSUES

* If you get a 'core quota exceeded' error, balance the `controllercount` parameter with the VM size (in `commonProfile.hardwareProfile`)

## TODO

* Use appropriate (RFC1178-compliant) hostnames
* Add ansible-based configuration to provision k8s packages
* Generate inventory file dynamically (also may need to templatize "ansible.cfg")
* Create a devcontainer with venv and VSCode-based environment



