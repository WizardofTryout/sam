#!/usr/bin/env bash
# Build, load and install a service into the kind mesh from a directory holding
# a Dockerfile and a charts/sam-node values.yaml (e.g. development/examples/calc-mcp).
# Extra args pass to helm (e.g. --set replicaCount=3); RELEASE overrides the
# release name to deploy the same directory as several nodes.
set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: $(basename "$0") <service-dir> [helm args...]" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
[[ -d "$1" ]] || { echo "not a directory: $1" >&2; exit 1; }
DIR="$(cd "$1" && pwd)"; shift
[[ -f "${DIR}/values.yaml" ]] || { echo "no values.yaml in ${DIR}" >&2; exit 1; }
NAME="$(basename "${DIR}")"
RELEASE="${RELEASE:-${NAME}}"

HELM="helm"
if ! command -v helm >/dev/null 2>&1; then
  [[ -x "${PROJECT_ROOT}/bin/helm" ]] || { echo "missing prerequisite: helm (install helm or place it in ./bin/helm)" >&2; exit 1; }
  HELM="${PROJECT_ROOT}/bin/helm"
fi

set -x
docker build -t "${NAME}:local" "${DIR}"
kind load docker-image --name sam-kind "${NAME}:local"
"${HELM}" --kube-context kind-sam-kind -n sam-kind upgrade --install "${RELEASE}" "${PROJECT_ROOT}/charts/sam-node" \
  -f "${PROJECT_ROOT}/development/kind/sam-node.values.yaml" \
  -f "${DIR}/values.yaml" "$@"
kubectl --context kind-sam-kind -n sam-kind rollout status "deployment/${RELEASE}-sam-node" --timeout=180s
