```bash
# 1. Load local Docker images into Kind
kind load docker-image springbook-backend:latest --name demolab
kind load docker-image springbook-frontend:latest --name demolab

# 2. Ensure MySQL secret exists (replace username/password as needed)
kubectl create secret generic mysql-secret \
  --from-literal=username=root \
  --from-literal=password=password \
  -n springbook-dev --dry-run=client -o yaml | kubectl apply -f -

# 3. Apply ConfigMap for backend (if not using full Helm/Argo sync)
# Note: templates/*.yaml contain Helm syntax; prefer rendering with Helm or use Argo sync.

# 4. Create vault-secrets placeholder (required by backend startup.sh)
# Backend expects /vault/secrets/databaseenv.txt; without this ConfigMap you get:
#   cat: /vault/secrets/databaseenv.txt: No such file or directory
kubectl create configmap backend-vault-placeholder \
  --from-literal=databaseenv.txt="" \
  -n springbook-dev --dry-run=client -o yaml | kubectl apply -f -

# 5. Sync ArgoCD ApplicationSet / Application
argocd app sync springbook-dev

# 6. Check pods and logs
kubectl get pods -n springbook-dev
kubectl logs -f <backend-pod-name> -n springbook-dev
kubectl logs -f <frontend-pod-name> -n springbook-dev

# 7. Access frontend service
curl http://localhost:32001



kubectl get applicationsets -n argocd
kubectl describe applicationset springbook -n argocd


kubectl get pods -n springbook-dev
kubectl describe pod <pod-name> -n springbook-dev
kubectl logs <pod-name> -n springbook-dev -c backendapp
kubectl logs <pod-name> -n springbook-dev -c init-mydb

# Debug inside a pod 
kubectl run -it --rm debug-backend --image=springbook-backend:latest --namespace=springbook-dev -- /bin/sh
# Inside pod:
ls -l /opt/bilarn
cat /opt/bilarn/application.properties

# CHEK CCOMFIG MAP AND SECRET 
kubectl get configmap -n springbook-dev
kubectl describe configmap backend-vault-placeholder -n springbook-dev
kubectl describe configmap backend-config -n springbook-dev
kubectl get secret -n springbook-dev
kubectl describe secret mysql-secret -n springbook-dev

# CHECK DEPLOYMENT 
kubectl get deploy -n springbook-dev
kubectl describe deploy backendapp -n springbook-dev
kubectl get deploy backendapp -n springbook-dev -o yaml | grep -A10 volumeMounts
kubectl get deploy backendapp -n springbook-dev -o yaml | grep -A10 env:

# ARGO RESYNC 
argocd app sync springbook-dev

# ACCES FRONTNEND
curl http://localhost:32001

# --- Backend error: "cat: /vault/secrets/databaseenv.txt: No such file or directory" ---
# Cause: startup.sh expects /vault/secrets/databaseenv.txt from ConfigMap backend-vault-placeholder.
# When using Argo CD ApplicationSet: the ConfigMap is in the Helm chart; sync the app so Argo creates it.
argocd app sync springbook-dev
argocd app get springbook-dev    # confirm Synced; check for ConfigMap in Resources
kubectl get configmap backend-vault-placeholder -n springbook-dev
# If still missing after sync, create manually then restart backend:
kubectl create configmap backend-vault-placeholder --from-literal=databaseenv.txt="" -n springbook-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment backendapp -n springbook-dev

```

---

## Helm commands to run the app (from project root)

Run from the **project root** (parent of `gitops-repo`).

```bash
# --- Prerequisites ---
docker --version
kubectl version --client
helm version
kind --version

# --- 1. Create Kind cluster (optional NodePort mapping for 32000/32001) ---
kind create cluster --name springbook-local
# Or with NodePort mapping so localhost:32000 (backend) and localhost:32001 (frontend) work:
cat <<EOF | kind create cluster --name springbook-local --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 32000
        hostPort: 32000
      - containerPort: 32001
        hostPort: 32001
EOF

kubectl cluster-info --context kind-springbook-local
kubectl get nodes

# --- 2. Create namespace ---
kubectl create namespace springbook
# For dev env (matches Argo CD):
kubectl create namespace springbook-dev

# --- 3. (Optional) Build and load images into Kind ---
docker build -t springbook-backend:local ./bilarn-springbook/backend
docker build -t springbook-frontend:local ./bilarn-springbook/frontend
kind load docker-image springbook-backend:local --name springbook-local
kind load docker-image springbook-frontend:local --name springbook-local

# --- 4. Install chart (default namespace: springbook) ---
helm install springbook ./gitops-repo/apps/springbook \
  --namespace springbook \
  --wait

# Install without private registry (no imagePullSecrets):
helm install springbook ./gitops-repo/apps/springbook \
  --namespace springbook \
  --set imagePullSecrets="" \
  --wait

# Install with local images (after kind load):
helm install springbook ./gitops-repo/apps/springbook \
  --namespace springbook \
  --set imagePullSecrets="" \
  --set backend.image.repository=springbook-backend \
  --set backend.image.tag=local \
  --set backend.image.pullPolicy=Never \
  --set frontend.image.repository=springbook-frontend \
  --set frontend.image.tag=local \
  --set frontend.image.pullPolicy=Never \
  --wait

# Install into dev namespace with dev values (same as Argo CD dev):
helm install springbook-dev ./gitops-repo/apps/springbook \
  --namespace springbook-dev \
  -f gitops-repo/apps/springbook/values.yaml \
  -f gitops-repo/enviroments/dev/values.yaml \
  --set imagePullSecrets="" \
  --wait

# --- 5. ECR / private registry: create pull secret then install ---
kubectl create secret docker-registry awsecr-cred \
  --docker-server=<ECR_URL> \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password) \
  -n springbook
helm install springbook ./gitops-repo/apps/springbook --namespace springbook --wait

# --- 6. List release and check resources ---
helm list -n springbook
helm list -n springbook-dev
kubectl get pods,svc -n springbook
kubectl get pods,svc -n springbook-dev

# --- 7. Upgrade release ---
helm upgrade springbook ./gitops-repo/apps/springbook \
  --namespace springbook \
  --set backend.image.tag=my-tag \
  --reuse-values

helm upgrade springbook ./gitops-repo/apps/springbook \
  -f gitops-repo/apps/springbook/values.yaml \
  -f my-local-values.yaml \
  --namespace springbook

# --- 8. Template / dry-run (debug without installing) ---
helm template springbook ./gitops-repo/apps/springbook -n springbook
helm template springbook-dev ./gitops-repo/apps/springbook -n springbook-dev -f gitops-repo/enviroments/dev/values.yaml
helm install springbook ./gitops-repo/apps/springbook -n springbook --dry-run --debug

# --- 9. Uninstall ---
helm uninstall springbook -n springbook
helm uninstall springbook-dev -n springbook-dev
kubectl delete namespace springbook
kubectl delete namespace springbook-dev
kind delete cluster --name springbook-local

# --- 10. Access (if Kind created with extraPortMappings) ---
# Frontend: http://localhost:32001
# Backend:  http://localhost:32000
curl http://localhost:32001
curl http://localhost:32000/actuator/health

# Port-forward if no NodePort mapping:
kubectl port-forward -n springbook svc/frontend-svc 32001:80
kubectl port-forward -n springbook svc/backend-svc 32000:8080
```

**Quick reference**

| Action           | Command |
|------------------|--------|
| Install (default) | `helm install springbook ./gitops-repo/apps/springbook -n springbook --wait` |
| Install (no pull secret) | `helm install springbook ./gitops-repo/apps/springbook -n springbook --set imagePullSecrets="" --wait` |
| Install (local images) | Add `--set backend.image.repository=springbook-backend --set backend.image.tag=local --set backend.image.pullPolicy=Never` (and frontend equivalents) |
| Install dev env | `helm install springbook-dev ./gitops-repo/apps/springbook -n springbook-dev -f gitops-repo/apps/springbook/values.yaml -f gitops-repo/enviroments/dev/values.yaml --set imagePullSecrets="" --wait` |
| List             | `helm list -n springbook` |
| Upgrade          | `helm upgrade springbook ./gitops-repo/apps/springbook -n springbook [--set ... \| -f ...]` |
| Template         | `helm template springbook ./gitops-repo/apps/springbook -n springbook` |
| Uninstall        | `helm uninstall springbook -n springbook` |