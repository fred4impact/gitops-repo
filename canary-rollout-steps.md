# Canary Deployment with Argo Rollouts (Spring Boot App) — Steps Only

This note outlines **steps and file preparation** for doing a canary-based deployment of the Spring Boot (backend) app using Argo Rollouts. No implementation here—only the sequence and what to prepare.

---

## 1. Prerequisites

- Install the **Argo Rollouts controller** in the cluster (separate from Argo CD).
- Ensure the **Rollout CRD** is available (`rollouts.argoproj.io`).
- Decide which environment(s) use canary (e.g. staging/prod only; dev may stay as a normal Deployment).

---

## 2. Decide What to Canary

- **Canary target:** The **backend** (Spring Boot) app only. Frontend and MySQL can stay as regular Deployments/StatefulSets.
- **Scope:** Prepare separate Rollout and Service manifests for the backend; leave other chart resources (frontend, MySQL, ConfigMaps, Secrets) as they are.

---

## 3. File Preparation (Separate Files for Spring Boot Canary)

Prepare or adjust the following **separate files** under the Spring Boot app (e.g. in `apps/springbook/templates/` or a dedicated `rollouts/` area):

| File / artifact | Purpose |
|-----------------|--------|
| **Backend Rollout manifest** | Replace (or conditionally use instead of) `backend-deployment.yaml` with a `Rollout` resource that defines the canary strategy (steps, traffic split, etc.). |
| **Stable Service** | A Service that always points to the stable ReplicaSet (current production version). |
| **Canary Service** | A Service that points to the canary ReplicaSet (new version). Argo Rollouts uses these two services for traffic splitting. |
| **Ingress or Gateway (optional)** | If you use Ingress, prepare rules (or a single Ingress with two backends) so traffic can be split between stable and canary Services (e.g. by header, weight, or host). |
| **AnalysisTemplate / AnalysisRun (optional)** | If you want automated promotion/pause (e.g. metrics, job success), prepare template and run definitions in separate files. |

Keep the **existing** backend Deployment template as an option (e.g. for dev) or remove it for environments that use the Rollout.

---

## 4. Steps to Introduce Canary (Order of Work)

1. **Install Argo Rollouts** in the cluster (controller + kubectl plugin optional but helpful).
2. **Add the Rollout CRD** if not already present (usually bundled with the Rollouts install).
3. **Create the backend Rollout manifest** (separate file) with:
   - Same pod spec as the current backend Deployment (image, env, probes, etc.).
   - `spec.strategy.canary` with steps (e.g. 20% → 50% → 100%), and references to stable/canary Services.
4. **Create or rename Services** so you have:
   - One **stable** Service (selector matching stable ReplicaSet).
   - One **canary** Service (selector matching canary ReplicaSet).  
   Argo Rollouts can manage these selectors via labels it adds to ReplicaSets.
5. **Optional:** Add an **Ingress (or Gateway)** that splits traffic between stable and canary Services (e.g. by weight or header), or use a service mesh if you have one.
6. **Optional:** Add **AnalysisTemplate** and reference it in the Rollout’s canary steps for automated analysis (e.g. success rate, latency).
7. **Wire the chart/values** so that:
   - For **canary environments** (e.g. staging, prod): the chart renders the **Rollout** + stable/canary Services (and optional Ingress/AnalysisTemplate).
   - For **non-canary** (e.g. dev): the chart can still render the original **Deployment** and a single Service.
8. **ApplicationSet / Argo CD:** No change to the ApplicationSet itself; point it to the same gitops repo. The same chart with different values (e.g. `canary.enabled: true` for prod) will sync the Rollout or Deployment accordingly.
9. **Deploy and test:** Sync the app (e.g. `argocd app sync springbook-staging`), then trigger a new rollout by updating the Rollout’s image (or image tag in values) and watch the canary steps.
10. **Promote / abort:** Use `kubectl argo rollouts promote` or `abort` (or the Rollouts UI) as needed; document these commands for your team.

---

## 5. Summary Checklist

- [ ] Argo Rollouts controller and CRD installed.
- [ ] Backend Rollout manifest created (separate file from Deployment).
- [ ] Stable and canary Services defined for the backend.
- [ ] Ingress/Gateway prepared (if used) for traffic split.
- [ ] Optional: AnalysisTemplate/AnalysisRun files prepared.
- [ ] Chart/values updated to switch between Deployment (dev) and Rollout + Services (canary envs).
- [ ] ApplicationSet still points at the same repo; canary is driven by chart values and Rollout spec.
- [ ] Steps 9–10 (sync, trigger rollout, promote/abort) documented for operators.

---

## 6. Argo Rollouts commands

Replace `<rollout-name>` with your backend Rollout name (e.g. `backendapp`), `<namespace>` with the app namespace (e.g. `springbook-staging`, `springbook-prod`).

### Install Argo Rollouts controller

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### Install kubectl Argo Rollouts plugin (optional, for CLI)

```bash
# macOS / Linux
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64.tar.gz
tar xzf kubectl-argo-rollouts-linux-amd64.tar.gz
sudo mv kubectl-argo-rollouts /usr/local/bin/

# macOS ARM (Apple Silicon)
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-arm64.tar.gz
tar xzf kubectl-argo-rollouts-darwin-arm64.tar.gz
sudo mv kubectl-argo-rollouts /usr/local/bin/
```

### Verify CRD and controller

```bash
kubectl get crd rollouts.argoproj.io
kubectl get pods -n argo-rollouts
```

### List and get Rollouts

```bash
kubectl get rollouts -n <namespace>
kubectl get rollout <rollout-name> -n <namespace>
kubectl describe rollout <rollout-name> -n <namespace>
kubectl argo rollouts list rollouts -n <namespace>
```

### Watch rollout status (live)

```bash
kubectl argo rollouts status <rollout-name> -n <namespace> --watch
```

### Trigger a new rollout (update image)

```bash
kubectl argo rollouts set image <rollout-name> <container-name>=<new-image>:<tag> -n <namespace>

# Example:
# kubectl argo rollouts set image backendapp backendapp=springbook-backend:v2 -n springbook-staging
```

Or update the Rollout spec in Git (image in values) and sync with Argo CD:

```bash
argocd app sync springbook-staging
```

### Promote (move canary to next step or full rollout)

```bash
kubectl argo rollouts promote <rollout-name> -n <namespace>
```

### Abort rollout (revert to stable)

```bash
kubectl argo rollouts abort <rollout-name> -n <namespace>
```

### Retry after abort or failed step

```bash
kubectl argo rollouts retry rollout <rollout-name> -n <namespace>
```

### Restart (restart all pods without new version)

```bash
kubectl argo rollouts restart <rollout-name> -n <namespace>
```

### Pause / resume

```bash
kubectl argo rollouts pause <rollout-name> -n <namespace>
kubectl argo rollouts resume <rollout-name> -n <namespace>
```

### View rollout history and revisions

```bash
kubectl argo rollouts history <rollout-name> -n <namespace>
kubectl argo rollouts rollout undo <rollout-name> -n <namespace>
```

### Open Rollouts UI (optional)

```bash
kubectl argo rollouts dashboard
# Then open http://localhost:3100 (or the port shown)
```

### Plain kubectl equivalents (if plugin not installed)

```bash
kubectl get rollout <rollout-name> -n <namespace> -w
kubectl patch rollout <rollout-name> -n <namespace> -p '{"spec":{"paused":true}}'   # pause
kubectl patch rollout <rollout-name> -n <namespace> -p '{"spec":{"paused":false}}'  # resume
```

---

*No implementation is included in this note; use it as a guide to prepare the separate files and follow the steps when you implement canary with Argo Rollouts for the Spring Boot app.*
