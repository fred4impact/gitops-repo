1. Install kind
2. create Kind cluster 
3. Install Argocd and get the password 
4. Check to make sure argocd pods are runnin g
5. Install Install the ApplicationSet controller
6. Verify the CRD exists
7. Apply your ApplicationSet again

# Install Kind and Create cluter

```bash 
kind create cluster --name demolab --config kind.yml
kubectl cluster-info
kubectl get nodes
kubectl config use-context kind-demolab

kubectl get nodes
kubectl get pods -A
kubectl get services -A
kubectl get deployments -A
kubectl get pods -n kube-system

# LOAD DOCKER IMAGE TO THE CLUSTER 
# CREATE NAEMSPACE springbook

kubectl create namespace springbook

kind load docker-image springbook-backend:latest --name demolab
kind load docker-image springbook-frontend:latest --name demolab

docker exec -it demolab-control-plane crictl images

# Install ArgoCD
```bash
kubectl create namespace argocd

kubectl apply -n argocd \
-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl get pods -n argocd

# Access ARGOCD UI 
kubectl port-forward svc/argocd-server -n argocd 8080:443

# GET ARGOCD PASSWORD
kubectl get secret argocd-initial-admin-secret \
-n argocd \
-o jsonpath="{.data.password}" | base64 -d

# BUILD IMAGES 
docker build -t springbook-backend:lastest .
docker build -t springbook-frontend:local .
docker images

# Load images 

kind load docker-image springbook-backend:latest --name demolab 
kind load docker-image springbook-frontend:lastest

# Install the ApplicationSet controller
kubectl apply -n argocd \
-f https://raw.githubusercontent.com/argoproj-labs/applicationset/stable/manifests/install.yaml

# verify it exists 
kubectl get crds | grep applicationset

kubectl get pods -n argocd

kubectl apply -f argocd/application-set-springbook.yaml

#Verify ArgoCD created the apps
kubectl get applications -n argocd

######################################
# 1 Create Kind cluster
1 create kind cluster
2 install ArgoCD
3 install ApplicationSet controller
4 build backend/frontend images
5 kind load docker-image
6 push gitops repo
7 apply ApplicationSet
8 ArgoCD creates springbook-dev/staging/prod
9 Helm deploys the chart
##########################################


