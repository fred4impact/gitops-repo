# MetalB
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        listenAddress: "0.0.0.0"
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        listenAddress: "0.0.0.0"
        protocol: TCP
      - containerPort: 32000
        hostPort: 32000
        protocol: TCP
      - containerPort: 32001
        hostPort: 32001
        protocol: TCP
      - containerPort: 32002
        hostPort: 32002
        protocol: TCP
  - role: worker
  - role: worker

  # Create Cluster
  ```bash 
  kind create cluster --name dev --config kind-config.yaml

  kubectl get nodes
```

# Install MetalB 
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

# Wait for Pods 
kubectl get pods -n metallb-system

Find Docker Network 
docker network inspect kind | grep Subnet

"Subnet": "172.18.0.0/16"
172.18.255.200 - 172.18.255.250

```
# metallb-config.yaml
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: advert
  namespace: metallb-system
```
# Apply
kubectl apply -f metallb-config.yaml

# Deploy  an example app
kubectl create deployment nginx --image=nginx

# expose it to loadbalanacer
kubectl expose deployment nginx --port=80 --type=LoadBalancer

kubectl get svc

# Access Service
curl http://172.18.255.201

. Why You Mapped Ports 80 / 443

This is typically done for Ingress controllers like:

NGINX Ingress Controller

Traefik

Example architecture:

Host:80
   ↓
kind control-plane container
   ↓
Ingress Controller
   ↓
Kubernetes Services
   ↓
Pods

This allows:

http://localhost




8. When to Use NodePort (32000–32002)

You mapped these ports so you can expose services like:

type: NodePort
nodePort: 32000

Access:

http://localhost:32000
9. Typical Local Dev Architecture
                Host Machine
             ┌─────────────────┐
             │ localhost:80    │
             │ localhost:443   │
             │ localhost:32000 │
             └────────┬────────┘
                      │
                extraPortMappings
                      │
           kind control-plane container
                      │
                 Kubernetes
                      │
           Ingress / NodePort / MetalLB
                      │
                    Pods

💡 Best practice for local development

Use this combination:

Component	Purpose
kind	local Kubernetes
MetalLB	LoadBalancer support
Ingress NGINX	routing domains
extraPortMappings	expose ingress to localhost