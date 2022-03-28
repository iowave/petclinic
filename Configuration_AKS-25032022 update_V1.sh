#Script de configuration de l'existant
#Définition des variable général
export RG=predprodaks
export LOCATION=westeurope
export VNET=vnetpetclinic
export AKSNAME=petclinicpreprod
export STORAGEACCT=devirestor0110
export CIDR=10.202
export ACR=pcregistre
export AGW=AppGatewayPetclinic
export AGWPIP=AppgatewayPubIP

#Création d'un groupe de ressource 
az group create --name $RG --location $LOCATION

#Création d'une ressource vnet
az network vnet create -g $RG -n $VNET --address-prefix $CIDR.0.0/16

#Création d'un subnet pour le cluster AKS, et un 2nd pour l'application Gateway rattaché a la ressource vnet
az network vnet subnet create --address-prefixes $CIDR.0.0/22 --name=AKSSubnet -g $RG --vnet-name $VNET
az network vnet subnet create --address-prefixes $CIDR.4.0/24 --name=AppGwSubnet -g $RG --vnet-name $VNET

#création d'un Azure Container Registery
az acr create --resource-group $RG --name $ACR --sku Basic
## List images in registry (None yet) 
az acr repository list --name $ACR --output table

#récupération du subet id dans un variable
 SUBNET_ID=$(az network vnet subnet show --resource-group $RG --vnet-name $VNET --name AKSSubnet --query id -o tsv)

#configuration du cluster
az aks create \
    --resource-group $RG \
    --name $AKSNAME \
    --node-count 2 \
    --node-vm-size standard_b2s \
    --generate-ssh-keys \
    --zones 1 2 \
    --attach-acr $ACR \
    --network-plugin azure \
    --vnet-subnet-id $SUBNET_ID \
    --enable-managed-identity


#Création d'une adresse ip publique
az network public-ip create -n $AGWPIP -g $RG --allocation-method Static --sku Standard
#déploiement de l'app gateway
az network application-gateway create -n $AGW -l $LOCATION -g $RG --sku Standard_v2 --public-ip-address $AGWPIP --vnet-name $VNET --subnet AppGwSubnet
az network application-gateway list -g $RG -o table

#Activation du module AGIC d'appgateway pour 
appgwId=$(az network application-gateway show -n $AGW -g $RG -o tsv --query "id") 
az aks enable-addons -n $AKSNAME -g $RG -a ingress-appgw --appgw-id $appgwId

#Connexion a AKS
sudo az aks get-credentials --resource-group $RG --name $AKSNAME 
#Création d'un NameSpace dans kubernetes
kubectl create ns petclinic

#Déploiement du petclinic-deployment.yaml 
kubectl apply -f petclinic-deployment.yaml

#Check de l'IP Publique
kubectl get all -n petclinic
kubectl get ingress -n petclinic
kubectl get deployment ingress-appgw-deployment -n kube-system  
kubectl get deployment ingress-appgw-deployment -n kube-system


