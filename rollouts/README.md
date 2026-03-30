# Rollouts (prod canary) – Spring Boot backend

This folder holds **prod-only** canary rollout manifests for the Spring Boot backend, used with [Argo Rollouts](https://argoproj.github.io/argo-rollouts/).

## Files

| File | Purpose |
|------|--------|
| `backend-rollout.yaml` | Rollout with canary strategy (20% → 50% → 100%, with pauses). |
| `backend-stable-service.yaml` | Service for the stable ReplicaSet (NodePort 32200). |
| `backend-canary-service.yaml` | Service for the canary ReplicaSet (ClusterIP). |
| `ingress-canary.yaml` | Optional Ingress for traffic split (e.g. NGINX canary annotations). |
| `analysis-template.yaml` | Optional AnalysisTemplate (Prometheus + Job-based health check). |

## Prerequisites

- **Namespace:** `springbook-prod` must exist.
- **Secrets:** `mysql-creds` (keys: `username`, `password`) in `springbook-prod`.
- **ConfigMap:** Backend config can stay in the Helm chart; Rollout uses env and probes only.
- **Argo Rollouts:** Controller and CRD installed in the cluster.

## Apply order

1. Create namespace (if not already created by Helm/Argo):  
   `kubectl create namespace springbook-prod`
2. Services first (Rollout references them):  
   `kubectl apply -f backend-stable-service.yaml -f backend-canary-service.yaml`
3. Rollout:  
   `kubectl apply -f backend-rollout.yaml`
4. Optional:  
   `kubectl apply -f ingress-canary.yaml`  
   `kubectl apply -f analysis-template.yaml`

## Using with the Helm chart (prod)

For prod, either:

- **Option A:** Disable the backend Deployment in prod values (`backend.enabled: false`) and deploy this Rollout folder via a separate Argo Application (pointing at this `rollouts/` path), or  
- **Option B:** Integrate these manifests into the Helm chart under `apps/springbook/templates/` with a condition (e.g. `canary.enabled: true`) and render them only for prod.

## Trigger and control

- **Trigger new canary:**  
  `kubectl argo rollouts set image backendapp backendapp=springbook-backend:<new-tag> -n springbook-prod`
- **Watch:**  
  `kubectl argo rollouts status backendapp -n springbook-prod --watch`
- **Promote / abort:**  
  `kubectl argo rollouts promote backendapp -n springbook-prod`  
  `kubectl argo rollouts abort backendapp -n springbook-prod`

See `canary-rollout-steps.md` in the repo root for the full command list.
