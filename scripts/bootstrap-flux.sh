#!/usr/bin/env bash
set -euo pipefail

# K3s GitOps Bootstrap Script - FluxCD
# Prerequisites: k3s installed, kubectl configured, flux CLI installed,
# and GITHUB_TOKEN exported in your shell if the repo is private.

GITHUB_USER="<YOUR_GITHUB_USER>"
REPO_NAME="k3s-gitops-bootstrap"
CLUSTER_NAME="homelab-01"
BRANCH="main"

echo "=== Bootstrapping FluxCD for K3s homelab cluster ==="

# Fail fast with a clear message instead of a cryptic error mid-script
for bin in kubectl flux; do
  command -v "${bin}" >/dev/null 2>&1 || {
    echo "ERROR: '${bin}' is not installed or not on PATH." >&2
    exit 1
  }
done

if [[ "${GITHUB_USER}" == "<YOUR_GITHUB_USER>" ]]; then
  echo "ERROR: edit this script and set GITHUB_USER to your GitHub username first." >&2
  exit 1
fi

# Verify cluster connection
kubectl get nodes

# Bootstrap flux into the cluster, creates flux-system namespace + deployments.
# --path here MUST match the "path" used by the flux-system Kustomization
# object in clusters/<cluster>/flux-system/kustomization-flux.yaml.
flux bootstrap git \
  --url="https://github.com/${GITHUB_USER}/${REPO_NAME}.git" \
  --branch="${BRANCH}" \
  --path="clusters/${CLUSTER_NAME}/flux-system" \
  --namespace=flux-system

echo "Flux bootstrap complete"
echo "Monitor flux reconciliation:"
echo "  flux get sources git"
echo "  flux get sources helm"
echo "  flux get kustomizations --watch"
echo "  flux get helmreleases --all-namespaces"
