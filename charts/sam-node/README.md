# sam-node

Deploys one SAM node into a Kubernetes cluster, optionally hosting a service
as a sidecar container. The node authenticates to the control plane with a
projected ServiceAccount token (Workload Identity Federation); the token's
`audience` must be listed in the control plane's `allowedAudiences`.

## Usage

A bare node (a caller / mesh participant with no local service):

```bash
helm install my-node charts/sam-node \
  --set controlPlaneUrl=http://sam-mesh-control-plane:8080
```

A node hosting an MCP service (see `development/examples/*/values.yaml` for
complete, working examples):

```yaml
controlPlaneUrl: http://sam-mesh-control-plane:8080
config:
  version: v1alpha1
  services:
    - type: mcp
      name: calculator
      description: Simple math operations
      target_url: http://127.0.0.1:7777/mcp
service:
  name: calc-mcp
  image: calc-mcp:local
```

Values files stack: keep environment wiring (`controlPlaneUrl`, extra args)
in a base file and the service description in its own, then pass both:
`helm install calc charts/sam-node -f base.yaml -f calc/values.yaml`
(later files win). The kind dev mesh ships such a base at
`development/kind/sam-node.values.yaml`.

The service container and the node share the pod's network, so `target_url`
points at `127.0.0.1:<port>`. Services declared in `config.services` are
advertised to the mesh via DHT and gossip; `config.attenuation` narrows what
the node's credential permits. Your `config` values are merged over the chart's
defaults and rendered as `sam-node.yaml` at startup — the chart rolls the pods
on config changes (checksum annotation).

## Values

| Key | Default | Meaning |
|-----|---------|---------|
| `controlPlaneUrl` | — (required) | Control plane URL the node enrolls with |
| `audience` | `sam-mesh-audience` | Projected token audience |
| `apiToken` | `devtoken` | Bearer token for the node's local REST API |
| `bindAddr` | `127.0.0.1:8080` | Node API bind address (loopback = pod-private) |
| `extraArgs` | `[]` | Extra sam-node args |
| `config` | empty services | Merged over the chart's defaults and rendered as `sam-node.yaml` |
| `service.image` | `""` | Service container image; empty = bare node |
| `service.name/command/env/ports/resources` | — | Service container spec |
| `image.repository/tag/pullPolicy` | `sam-node:local` | Node image |
| `replicaCount` | `1` | Each replica enrolls as its own mesh node |

## Dynamic registration (alternative to `config.services`)

A running node also accepts `POST /sam/service/register` on its API
(`bindAddr`, bearer `apiToken`) with a JSON body
`{"service":{"type":"mcp","name":"x","description":"…"},"targetUrl":"http://…"}`.
Registrations are in-memory: after a node restart the registrar must
re-register. Static `config.services` entries need no such care.
