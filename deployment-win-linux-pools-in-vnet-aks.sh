#!/bin/bash

# deployment script to create a resource group and AKS cluster in an existing VNET with Windows and Linux node pools with virtual machine scale sets

AKSResourceGroupName=""
AKSClusterName=""
AKSClusterLocation=""
AKSClusterLinuxNodePoolName=""
AKSClusterLinuxNodePoolCount=""
AKSClusterWindowsNodePoolName=""
AKSClusterWindowsNodePoolCount=""
AKSClusterVMSize=""
AKSClusterServicePrincipalAppId="GENERATED AT RUNTIME"
AKSClusterServicePrincipalPassword="GENERATED AT RUNTIME"
AKSClusterVNETName=""
AKSClusterVNETId="GENERATED AT RUNTIME"
AKSClusterSubnetName=""
AKSClusterVNETSubnetId="GENERATED AT RUNTIME"
AKSUserWindows=""
AKSPasswordWindows=""

# Install the aks-preview extension
az extension add --name aks-preview

# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview

# register windows preview feature
az feature register --name WindowsPreview --namespace Microsoft.ContainerService

# lookup feature
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/WindowsPreview')].{Name:name,State:properties.state}"

# register provider
az provider register --namespace Microsoft.ContainerService

# create resource group
az group create --name $RESOURCE_GROUP --location $AKSClusterLocation

# create service principal to cluster
az ad sp create-for-rbac -n $AKSClusterName

# get service principal id
AKSClusterServicePrincipalAppId=$(az ad sp list --display-name $AKSClusterName --query "[].appId" -o tsv)

# reset service principal password
AKSClusterServicePrincipalPassword=$(az ad sp credential reset --name $AKSClusterName --query password -o tsv)

# wait 2 minutes for propagation
sleep 2m

# assign vnet id
AKSClusterVNETId=$(az network vnet show --resource-group $AKSResourceGroupName --name $AKSClusterVNETName --query id -o tsv)

# assign permissions to the virtual network
az role assignment create --assignee $AKSClusterServicePrincipalAppId --scope $AKSClusterVNETId --role Contributor

# assign vnet subnet id
AKSClusterVNETSubnetId=$(az network vnet subnet show --resource-group $AKSResourceGroupName --vnet-name $AKSClusterVNETName --name $AKSClusterSubnetName --query id -o tsv)

# create cluster
az aks create \
    --resource-group $AKSResourceGroupName \
    --name $AKSClusterName \
    --nodepool-name $AKSClusterLinuxNodePoolName \
    --node-count $AKSClusterLinuxNodePoolCount \
    --node-vm-size $AKSClusterVMSize \
    --generate-ssh-keys \
    --network-plugin azure \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $AKSClusterVNETSubnetId \
    --service-principal $AKSClusterServicePrincipalAppId \
    --client-secret $AKSClusterServicePrincipalPassword \
    --windows-admin-username $AKSUserWindows \
    --windows-admin-password $AKSPasswordWindows \
    --enable-addons monitoring \
    --enable-vmss \
    --kubernetes-version 1.14.6

# add windows node pool
az aks nodepool add \
    --resource-group $AKSResourceGroupName \
    --cluster-name $AKSClusterName \
    --os-type Windows \
    --name $AKSClusterWindowsNodePoolName \
    --node-count $AKSClusterWindowsNodePoolCount \
    --kubernetes-version 1.14.6
