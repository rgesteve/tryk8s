#!/usr/bin/env python

import os
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.network import NetworkManagementClient

# Get your Azure credentials (replace with your preferred method)
#subscription_id = str(os.environ["AZURE_SUBSCRIPTION_ID"].strip())  # claims that it's malformed if it comes from AZURE_SUBSCRIPTION_ID=$(az account list | jq '.[0].id')
subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
resource_group_name = os.environ["RGNAME"]

print(f"Should be using subscription {subscription_id} and resource group {resource_group_name}..")

controller_template="""
Host controller
 Hostname {0}
 User {1}
 IdentityFile ~/.ssh/azurevmtest_rsa
 ForwardAgent yes
"""

worker_template="""
Host {0}
 Hostname {1}
 ProxyJump controller
"""

# Create a ComputeManagementClient
credential = DefaultAzureCredential();
client = ComputeManagementClient(subscription_id=subscription_id, credential=credential)
net_client = NetworkManagementClient(subscription_id=subscription_id, credential=credential)

# List VMs in the resource group
vms = client.virtual_machines.list(resource_group_name=resource_group_name)

output = ""

# Iterate and print VM information
for vm in vms:
    #print(f"Name: {vm.name}")
    #print(f"Location: {vm.location}")
    #print(f"Tags: {vm.tags}")

    # # Add more properties as needed
    #print(",".join(d for d in dir(vm) if not d.startswith("_")))

    # Unfortunate and convoluted way of obtaining public IP of selected instance
    # cfr https://github.com/Azure/azure-sdk-for-python/issues/897
    ni_reference = vm.network_profile.network_interfaces[0]
    ni_reference = ni_reference.id.split('/')
    ni_group = ni_reference[4]
    ni_name = ni_reference[8]
    net_interface = net_client.network_interfaces.get(ni_group, ni_name)
    if not ('applicationRole' in vm.tags):
        continue
    if vm.tags['applicationRole'] == 'worker':
        #print(",".join(d for d in dir(net_interface.ip_configurations[0]) if not d.startswith("_")))
        #print(f"private ip: {net_interface.ip_configurations[0].private_ip_address}.")
        output += worker_template.format(vm.name, net_interface.ip_configurations[0].private_ip_address)
        continue
    ip_reference = net_interface.ip_configurations[0].public_ip_address
    if ip_reference:
        ip_reference = ip_reference.id.split('/')
        ip_group = ip_reference[4]
        ip_name = ip_reference[8]
        public_ip = net_client.public_ip_addresses.get(ip_group, ip_name)
        public_ip = public_ip.ip_address
        output += controller_template.format(public_ip, "rgesteve")
        #print(f"Public ip: {public_ip}")

with open("ssh_config", mode="w") as f:
    f.write(output)

print("Done!")



    
