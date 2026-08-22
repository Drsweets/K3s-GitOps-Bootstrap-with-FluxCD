# K3s GitOps Bootstrap with FluxCD

Homelab GitOps project using K3s lightweight Kubernetes, FluxCD v2, Kustomize & Helm.

## Tech Stack
- K3s: lightweight local Kubernetes distribution
- FluxCD v2: GitOps continuous reconciliation engine
- Kustomize: Kubernetes manifest management
- Helm & Flux HelmRelease: declarative Helm chart deployment
- Longhorn: cloud-native distributed persistent storage
- MetalLB: bare-metal load balancer
- kube-prometheus-stack: monitoring & alerting
- Traefik: ingress controller
- cert-manager: certificate management
- whoami: demo web workload

## Workflow
1. Install K3s on bare-metal / VM nodes (disable the built-in Traefik if you
   want the Flux-managed one to be the only ingress controller: `--disable traefik`).
2. Fork/clone this repo and push it to your own GitHub account.
3. Edit `GITHUB_USER` in `scripts/bootstrap-flux.sh` and the `url:` in
   `clusters/homelab-01/flux-system/gitrepository.yaml`.
4. If the repo is private, create a Kubernetes secret named `flux-system` in
   the `flux-system` namespace with your Git credentials and uncomment the
   `secretRef` in `gitrepository.yaml`. If it's public, leave it commented out.
5. Run `./scripts/bootstrap-flux.sh` to install Flux and point it at this repo.
6. Flux reconciles infrastructure (Longhorn, MetalLB) then apps (monitoring,
   ingress, demo-web) from Git into the cluster.
7. Every `git push` to `main` triggers automatic sync to the cluster.

## Commands for validation

```shell
# Check flux status
flux get sources git
flux get sources helm
flux get kustomizations --watch
flux get helmreleases -A

# Check cluster components
kubectl get pods -n longhorn-system
kubectl get pods -n metallb-system
kubectl get pods -n monitoring
kubectl get pods -n ingress
kubectl get pods -n cert-manager
kubectl get ingress -n demo-web
```

## Known first-boot gotchas
- **MetalLB IPAddressPool race**: the `IPAddressPool`/`L2Advertisement` CRDs
  don't exist until the MetalLB HelmRelease finishes installing. Flux will
  show a failure on the very first reconcile and self-heal on the next
  interval — this is expected, not a bug you need to fix.
- **Traefik double-install**: K3s ships its own Traefik by default. Either
  disable it at install time or don't deploy the Flux-managed Traefik.
- **kube-prometheus-stack on K3s**: the control-plane component scrape jobs
  (`kubeControllerManager`, `kubeScheduler`, `kubeEtcd`, `kubeProxy`) are
  disabled in `values` because K3s doesn't expose them the way kubeadm
  clusters do.
