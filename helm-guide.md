# Helm Guide: Deploy Springbook Locally with Kind

This guide walks you through running the **springbook** Helm chart (from `gitops-repo/apps/springbook`) on a local Kubernetes cluster using **Kind** (Kubernetes in Docker), so you can try out the app without a cloud cluster.

---

## Prerequisites

Install these on your machine:

| Tool    | Purpose                    | Install |
|---------|----------------------------|--------|
| **Docker** | Run Kind nodes             | [docker.com](https://docs.docker.com/get-docker/) |
| **kubectl** | Talk to the cluster        | `brew install kubectl` (macOS) or [kubectl install](https://kubernetes.io/docs/tasks/tools/) |
| **Helm**    | Install/upgrade the chart  | `brew install helm` (macOS) or [helm.sh](https://helm.sh/docs/intro/install/) |
| **Kind**    | Local Kubernetes cluster   | `brew install kind` (macOS) or [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |

Check versions:

```bash
docker --version
kubectl version --client
helm version
kind --version
```

---

## 1. Create a Kind cluster

Create a cluster (optional: map NodePorts so you can hit frontend/backend from the host):

```bash
# Create cluster (default name: kind)
kind create cluster --name springbook-local

# Optional: create cluster with NodePort mapping so http://localhost:32001 (frontend) and http://localhost:32000 (backend) work
cat <<EOF | kind create cluster --name springbook-local --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 32000  # backend NodePort
        hostPort: 32000
      - containerPort: 32001  # frontend NodePort
        hostPort: 32001
EOF
```

Point `kubectl` at the new cluster:

```bash
kubectl cluster-info --context kind-springbook-local
kubectl get nodes
```

---

## 2. (Optional) Use your own backend/frontend images with Kind

The chart defaults to ECR images. For local testing you can:

**Option A – Use public/placeholder images**  
Override in step 3 with `--set` to use images that don’t need a pull secret (e.g. a public backend/frontend image or `nginx` for frontend).

**Option B – Build and load images into Kind**  
If your app lives in `bilarn-springbook`:

```bash
# Build images (example names)
docker build -t springbook-backend:local ./bilarn-springbook/backend
docker build -t springbook-frontend:local ./bilarn-springbook/frontend

# Load into Kind so the cluster can use them without a registry
kind load docker-image springbook-backend:local --name springbook-local
kind load docker-image springbook-frontend:local --name springbook-local
```

Then in step 3 use `--set backend.image.repository=springbook-backend --set backend.image.tag=local` (and similarly for frontend).

---

## 3. Deploy the Springbook Helm chart

From the **project root** (parent of `gitops-repo`):

```bash
# Create namespace (optional; Helm can create it)
kubectl create namespace springbook

# Install the chart from the gitops-repo path
helm install springbook ./gitops-repo/apps/springbook \
  --namespace springbook \
  --wait
```

**If you use ECR (or any private registry)** you must create the image pull secret in the namespace first:

```bash
kubectl create secret docker-registry awsecr-cred \
  --docker-server=<ECR_URL> \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password) \
  -n springbook
```

**If you are testing without private images** (e.g. only MySQL + placeholders, or images loaded via `kind load`), disable the default pull secret so the chart doesn’t reference a missing secret:

```bash
helm install springbook ./gitops-repo/apps/springbook \
  --namespace springbook \
  --set imagePullSecrets="" \
  --wait
```

**Example with local images** (after `kind load docker-image`):

```bash
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
```

---

## 4. Check the release and pods

```bash
helm list -n springbook
kubectl get pods,svc -n springbook
```

Wait until all pods are `Running` (MySQL may take 30–60s). If something is stuck:

```bash
kubectl describe pod -n springbook -l app.kubernetes.io/name=springbook
kubectl logs -n springbook -l app.kubernetes.io/name=springbook --tail=50
```

---

## 5. Access the app

**If you created the cluster with `extraPortMappings` (step 1):**

- Frontend: **http://localhost:32001**
- Backend API: **http://localhost:32000**

**If you used plain `kind create cluster`** (no port mapping), use port-forward:

```bash
# Frontend
kubectl port-forward -n springbook svc/frontend-svc 32001:80

# In another terminal: Backend
kubectl port-forward -n springbook svc/backend-svc 32000:8080
```

Then open **http://localhost:32001** (frontend) and **http://localhost:32000** (backend).

---

## 6. Upgrade / change values

Edit values or override from the command line, then upgrade:

```bash
helm upgrade springbook ./gitops-repo/apps/springbook \
  --namespace springbook \
  --set backend.image.tag=my-tag \
  --reuse-values
```

Or use a custom values file:

```bash
helm upgrade springbook ./gitops-repo/apps/springbook \
  -f gitops-repo/apps/springbook/values.yaml \
  -f my-local-values.yaml \
  --namespace springbook
```

---

## 7. Uninstall and delete the cluster

```bash
helm uninstall springbook -n springbook
kubectl delete namespace springbook

kind delete cluster --name springbook-local
```

---

## Quick reference: commands you need

| Step            | Command |
|-----------------|--------|
| Create cluster  | `kind create cluster --name springbook-local` (or with config above for NodePorts) |
| Install chart   | `helm install springbook ./gitops-repo/apps/springbook -n springbook [--set ...]` |
| List releases   | `helm list -n springbook` |
| Status          | `kubectl get pods,svc -n springbook` |
| Access (if ports mapped) | Frontend: http://localhost:32001 — Backend: http://localhost:32000 |
| Access (port-forward)    | `kubectl port-forward -n springbook svc/frontend-svc 32001:80` and same for `backend-svc 32000:8080` |
| Upgrade         | `helm upgrade springbook ./gitops-repo/apps/springbook -n springbook [options]` |
| Uninstall       | `helm uninstall springbook -n springbook` then `kind delete cluster --name springbook-local` |

Using this flow you can run the same Helm chart that Argo CD uses in dev/staging/prod (e.g. from `application-set-springbook.yaml`) locally on Kind and try out the app before pushing changes.
