# k3s-gitops-bootstrap

Resume-ready homelab GitOps project: K3s + FluxCD v2 + Kustomize + Helm,
Longhorn, MetalLB, kube-prometheus-stack, Traefik, cert-manager, and a
`whoami` demo app.

See `docs/setup.md` for the full walkthrough and validation commands.

## What was fixed vs. the original draft

This repo was corrected from an earlier draft that had several bugs that
would have stopped it from working. In order of severity:

1. **Missing `HelmRepository` sources (critical).** Every `HelmRelease`
   referenced a `sourceRef` of `kind: HelmRepository`, but no
   `HelmRepository` object was ever defined anywhere in the repo. Flux would
   have failed to resolve every single chart. Added
   `helmrepository.yaml`/`helmrepository-*.yaml` for Longhorn, MetalLB,
   prometheus-community, Traefik, and cert-manager.

2. **Conflicting Helm mechanisms (critical).** Each `kustomization.yaml`
   also had a `helmCharts:` block, which is Kustomize's *own* built-in Helm
   chart inflator (`kustomize build --enable-helm`) — a completely separate
   mechanism from Flux's `HelmRelease`/`helm-controller`. Having both meant
   the same chart could be installed two different ways, or the inflator
   block would silently do nothing (plain Flux `kustomize-controller` builds
   don't pass `--enable-helm`). Removed all `helmCharts:` blocks.

3. **Non-standard hyphen characters everywhere (critical).** The original
   used the Unicode "non-breaking hyphen" (U+2011, `‑`) instead of a normal
   ASCII hyphen (`-`) in directory names, file names, YAML values, and the
   bootstrap script's `CLUSTER_NAME`/path variables. On a real filesystem
   and in `bash`, `‑` and `-` are different characters — this would break
   `flux bootstrap --path=...`, git clone URLs, and directory references.
   Rewritten with plain ASCII hyphens throughout.

4. **cert-manager CRDs never installed.** The chart needs `crds.enabled:
   true` in `values`, or the `Certificate`/`ClusterIssuer`/`Issuer` CRDs
   never get created and every downstream cert-manager resource fails.
   Added under `apps/ingress/helmrelease-certmanager.yaml`.

5. **`demo-web` namespace never created.** `apps/demo-web/kustomization.yaml`
   sets `namespace: demo-web` on all resources but nothing ever created that
   namespace, so applying it would fail. Added `namespace.yaml`.

6. **`GitRepository` pointed at a secret that may not exist.** The original
   always referenced `secretRef: name: flux-system`, which only exists for
   private repos with credentials configured. For a public repo (the
   default assumption here) that reference makes reconciliation fail.
   Commented it out with instructions for when to re-enable it.

7. **`whoami-ingress` had no `ingressClassName`.** Left ambiguous, especially
   since K3s ships its own Traefik alongside the one this project can
   install — added `ingressClassName: traefik` and a note about the
   double-Traefik conflict (K3s's built-in one needs `--disable traefik` at
   install time if you want the Flux-managed one).

8. **`validation: client` on the flux-system `Kustomization`.** That field
   was removed from the `kustomize.toolkit.fluxcd.io/v1` API (it's a
   leftover from older Flux `v1beta2` examples) and would be rejected by a
   current Flux CRD schema. Removed, and added `wait`/`timeout` instead.

9. **Cluster-wide apply ordering.** The original had the top-level
   `clusters/homelab-01/kustomization.yaml` include `flux-system` alongside
   `infrastructure` and `apps` — a Kustomization that includes the very
   `GitRepository`/`Kustomization` objects that are reconciling it. Split so
   `flux-system` is bootstrapped by `flux bootstrap` directly, and the
   top-level Kustomization only aggregates `infrastructure` + `apps`.

10. **Minor hardening**: added CPU/memory `resources` to the `whoami`
    Deployment (none were set before), quoted all Helm chart `version`
    fields (unquoted YAML like `1.16.0` can occasionally be mis-parsed),
    added `kubeControllerManager`/`kubeScheduler`/`kubeEtcd`/`kubeProxy:
    enabled: false` to kube-prometheus-stack since K3s doesn't expose those
    the way kubeadm clusters do, and added prerequisite checks + clearer
    output to `scripts/bootstrap-flux.sh`.

## Before you run this

- Replace `<YOUR_GITHUB_USER>` in `scripts/bootstrap-flux.sh` and
  `clusters/homelab-01/flux-system/gitrepository.yaml`.
- Update the MetalLB `addresses` range in
  `clusters/homelab-01/infrastructure/metallb/ipaddresspool.yaml` to a free
  block on your own LAN.
- Chart versions (Longhorn, MetalLB, kube-prometheus-stack, Traefik,
  cert-manager) are pinned to specific releases — check each project's
  Helm repo / Artifact Hub page for anything newer before you deploy.
