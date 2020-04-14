#!/bin/bash
clear

# NOTE: before run this script ensure you are logged in Azure by using az login command.

read -p "Introduce a lowercase unique alias for your deployment (max length suggested of 6 chars): " DeploymentAlias
ResourceGroupName=$DeploymentAlias"-dapr-workshop"
AKSClusterName=$DeploymentAlias"aks01"
Location="westus2"
AKSK8sVersion="1.14.8"
ContainerRegistryName=$DeploymentAlias"cr01"
ServicePrincipal=$DeploymentAlias"-dapr-workshop-sp"

# PRINT
echo "**********************************************************************"
echo " CREATING: SERVICE PRINCIPAL"
echo ""
echo " Description:"
echo ""
echo " An identity created for use with applications, hosted services, and "
echo " automated tools to access Azure resources."
echo "**********************************************************************"

az ad sp create-for-rbac -n $ServicePrincipal

# get app id
SP_APP_ID=$(az ad sp show --id http://$ServicePrincipal --query appId -o tsv)
echo "Service Principal AppId: "$SP_APP_ID

# get password
SP_APP_PASSWORD=$(az ad sp credential reset --name $ServicePrincipal --query password -o tsv)
echo "Service Principal Password: "$SP_APP_PASSWORD

# wait aad propagation
sleep 60s

# PRINT
echo "**********************************************************************"
echo " CREATING: GENERAL RESOURCE GROUP"
echo ""
echo " Description:"
echo ""
echo " A container that holds related resources for an Azure solution."
echo "**********************************************************************"

# create cluster resource group
az group create --name $ResourceGroupName --location $Location

# get group id
GROUP_ID=$(az group show -n $ResourceGroupName --query id -o tsv)

# role assignment 
az role assignment create --assignee $SP_APP_ID --scope $GROUP_ID --role "Contributor"

# PRINT
echo "**********************************************************************"
echo " CREATING: CONTAINER REGISTRY"
echo ""
echo " Description:"
echo ""
echo " A registry of Docker and Open Container Initiative (OCI) images, with"
echo " support for all OCI artifacts."
echo "**********************************************************************"

# create acr
az acr create -n $ContainerRegistryName -g $ResourceGroupName --sku basic --admin-enabled true

# get container registry id
ContainerRegistryId=$(az acr show -n $ContainerRegistryName -g $ResourceGroupName --query id -o tsv)

# get acr id 
ACR_ID=$(az acr show -n $ContainerRegistryName -g $ResourceGroupName --query id -o tsv)

# role assignment 
az role assignment create --assignee $SP_APP_ID --scope $ACR_ID --role "Contributor"

# PRINT
echo "**********************************************************************"
echo " CREATING: AKS CLUSTER"
echo ""
echo " Description:"
echo ""
echo " Highly available, secure, and fully managed Kubernetes service."
echo "**********************************************************************"

# create cluster
az aks create \
    --name $AKSClusterName \
    --resource-group $ResourceGroupName \
    --node-count 1 \
    --kubernetes-version $AKSK8sVersion \
    --service-principal $SP_APP_ID \
    --client-secret $SP_APP_PASSWORD \
    --generate-ssh-keys

# update cluster
az aks update \
    --resource-group $ResourceGroupName \
    --name $AKSClusterName \
    --attach-acr $ACR_ID

echo ""
echo "****************************CALL TO ACTION****************************"
echo ""
echo "Deployment alias: "$DeploymentAlias
echo "Resource group: "$ResourceGroupName
echo "Location: "$Location
echo "Cluster name: "$AKSClusterName
echo "Kubernetes version: "$AKSK8sVersion
echo "Container registry: "$ContainerRegistryName
echo "Service principal name: "$ServicePrincipal
echo "Service principal id: "$SP_APP_ID
echo "Service principal password: "$SP_APP_PASSWORD
echo ""
echo "****************************CALL TO ACTION****************************"
echo ""
