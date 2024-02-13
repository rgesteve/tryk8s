@description('The name of you Virtual Machine.')
param vmname    string
param vmuser    string
param controllercount int = 2
// @secure()
// param vmpass    string
@description('Unique DNS Name for the Public IP used to access the Virtual Machine.')
param dnsLabelPrefix string = toLower('${vmname}-${uniqueString(resourceGroup().id)}')
@description('SSH Key for the Virtual Machine.')
@secure()
param publickey string

// This issues a warning
var location = resourceGroup().location

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name      : '${vmname}-nsg'
  location  : location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          priority                 : 110
          protocol                 : 'Tcp'
          sourcePortRange          : '*'
          destinationPortRange     : '22'
          sourceAddressPrefix      : '*'
          destinationAddressPrefix : '*'
          access                   : 'Allow'
          direction                : 'Inbound'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: '${vmname}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-07-01' = {
  parent: vnet
  name: '${vmname}-subnet'
  properties: {
    addressPrefix: '10.0.0.0/24'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2020-07-01' = {
  name: '${vmname}-pip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-07-01' = {
  name: '${vmname}-nic'
  location: location
  properties: {
    ipConfigurations: [
        {
          name: 'ifcfg'
          properties: {
            publicIPAddress: {
              id: pip.id
            }
            subnet         : {
              id: subnet.id
            }
            privateIPAllocationMethod: 'Dynamic'
          }
        }
    ]
  }
}

resource jumpbox 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name      : vmname
  location  : location
  tags : {
    applicationRole: 'controller'
  }
  properties: {
    hardwareProfile: {
      //vmSize: 'Standard_B2ms'
      vmSize: 'Standard_D8_v5'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts'
        version: 'latest'
      }
      osDisk: {
        name: '${vmname}-osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          // storageAccountType: 'Premium_LRS'  // Standard_D8_v5 does not support premium storage
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 64
      }
    }
    osProfile: {
      computerName : vmname
      adminUsername: vmuser
      //adminPassword: vmpass
      // TODO: Re-enable SSH authentication
      linuxConfiguration: {
        // disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${vmuser}/.ssh/authorized_keys'
              keyData: publickey
            }
          ]
        }
      }
      // customData: base64(loadTextContent('cloud-init.yaml'))
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource nicvm 'Microsoft.Network/networkInterfaces@2020-07-01' = {
  name: '${vmname}-nicvm'
  location: location
  properties: {
    ipConfigurations: [
        {
          name: 'ifcfg'
          properties: {
            subnet         : {
              id: subnet.id
            }
            privateIPAllocationMethod: 'Dynamic'
          }
        }
    ]
  }
}

var nicNameLinux = 'nic-linux-'

// https://github.com/microsoft/Federal-App-Innovation-Community/blob/2f31d83a1f1b86753349a437538984206b620964/topics/kubernetes/solutions/aro-kubernetes/hub-spoke-deployment/landing-zone.bicep#L569
resource nicNameLinuxResource 'Microsoft.Network/networkInterfaces@2020-07-01' = [for i in range(0, controllercount): {
  name: '${nicNameLinux}${i + 1}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            // id: '${vnetSpoke.id}/subnets/${spokeNetwork.subnetName}'
	    id: subnet.id
          }
        }
      }
    ]
  }
}]

var commonProfile = {
  hardwareProfile : {
    vmSize: 'Standard_D4_v5'
  }
  storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts'
        version: 'latest'
      }
      osDisk: {
        // name: '${vmname}-osdisk-worker' // avoid naming when sharing the spec across VM creation
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          // storageAccountType: 'Premium_LRS'  // Standard_D8_v5 does not support premium storage
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 64
      }
    }
    osProfile: {
      computerName : vmname
      adminUsername: vmuser
      //adminPassword: vmpass
      // TODO: Re-enable SSH authentication
      linuxConfiguration: {
        // disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${vmuser}/.ssh/authorized_keys'
              keyData: publickey
            }
          ]
        }
      }
   }
}

resource vmNameLinuxResource 'Microsoft.Compute/virtualMachines@2019-07-01' = [for i in range(0, controllercount): {
  name: '${vmname}worker${i + 1}'
  location: location
  dependsOn:[
    nicNameLinuxResource
  ]
  tags : {
    applicationRole: 'worker'
  }
  properties: {
    hardwareProfile : commonProfile.hardwareProfile
    storageProfile : commonProfile.storageProfile
    osProfile: commonProfile.osProfile
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${nicNameLinux}${i + 1}')
        }
      ]
    }
  }
}]

output adminUsername string = vmuser
output hostname string = pip.properties.dnsSettings.fqdn
// should get this from `az vm list` instead
//output privateIPAddress string = nicvm.properties.ipConfigurations[0].properties.privateIPAddress
output sshCommand string = 'ssh ${vmuser}@${pip.properties.dnsSettings.fqdn}'
