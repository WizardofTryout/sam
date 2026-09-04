#!/usr/bin/env bash
# Build, load and install a development/examples/<example> into the kind mesh.
# Extra args pass to helm, e.g.: deploy-kind-example.sh code-reviewer-pool/reviewer --set replicaCount=3
set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: $(basename "$0") <example> [helm args...]" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXAMPLE="$1"; shift
DIR="${PROJECT_ROOT}/development/examples/${EXAMPLE}"
[[ -f "${DIR}/values.yaml" ]] || { echo "example '${EXAMPLE}' not found (no values.yaml in development/examples/${EXAMPLE})" >&2; exit 1; }
NAME="$(basename "${EXAMPLE}")"

HELM="helm"
if ! command -v helm >/dev/null 2>&1; then
  [[ -x "${PROJECT_ROOT}/bin/helm" ]] || { echo "missing prerequisite: helm (install helm or place it in ./bin/helm)" >&2; exit 1; }
  HELM="${PROJECT_ROOT}/bin/helm"
fi

set -x
docker build -t "${NAME}:local" "${DIR}"
kind load docker-image --name sam-kind "${NAME}:local"
"${HELM}" --kube-context kind-sam-kind -n sam-kind upgrade --install "${NAME}" "${PROJECT_ROOT}/charts/sam-node" \
  -f "${PROJECT_ROOT}/development/kind/sam-node.values.yaml" \
  -f "${DIR}/values.yaml" "$@"
kubectl --context kind-sam-kind -n sam-kind rollout status "deployment/${NAME}-sam-node" --timeout=180s
