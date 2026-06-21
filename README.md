# unify-edge-runner

Helm chart for deploying CloudBees Unify Edge Runners as a Kubernetes StatefulSet.

## Prerequisites

- Kubernetes 1.21+
- Helm 3
- A CloudBees Unify organisation ID and a PAT with edge runner permissions

## Installation

```bash
helm repo add unify-edge-runner https://stubrowncloudbees.github.io/unify-edge-runner
helm repo update

helm install edge-runner unify-edge-runner/unify-edge-runner \
  --set runner.orgId='YOUR-ORG-ID' \
  --set runner.name='k8s-home' \
  --set runner.labels='self-hosted,k8s' \
  --set runner.pat='YOUR_PAT_HERE' \
  --set binaryUrl='https://downloads.example.com/cloudbees-runner/linux/amd64/cloudbees-runner'
```

Each replica registers in Unify as `<name>-<index>` — e.g. `k8s-home-0`, `k8s-home-1`.

## Optional: Kubeconfig mount

Mount a kubeconfig so jobs can use `kubectl` and `helm`:

```bash
kubectl create secret generic edge-runner-kubeconfig \
  --from-file=config=/path/to/kubeconfig

helm install edge-runner unify-edge-runner/unify-edge-runner \
  --set kubeconfig.enabled=true \
  [... other values ...]
```

## Optional: SSH mount

Mount SSH keys for private Git repository access:

```bash
kubectl create secret generic edge-runner-ssh \
  --from-file=id_rsa=/path/to/private_key \
  --from-file=known_hosts=/path/to/known_hosts

helm install edge-runner unify-edge-runner/unify-edge-runner \
  --set ssh.enabled=true \
  [... other values ...]
```

## Scale

```bash
helm upgrade edge-runner unify-edge-runner/unify-edge-runner \
  --reuse-values \
  --set replicaCount=3
```

## Upgrade

```bash
helm repo update
helm upgrade edge-runner unify-edge-runner/unify-edge-runner --reuse-values
```

## PAT rotation

```bash
kubectl create secret generic edge-runner-pat \
  --from-literal=pat='YOUR_NEW_PAT' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart statefulset/edge-runner
```

## Known limitations

- Tools (apt, kubectl, helm) are installed at container startup. This adds latency and requires external network access. A pre-built image would eliminate this.
- PVCs created by `volumeClaimTemplates` are not deleted when the release is deleted. Delete manually to force re-registration:
  ```bash
  kubectl delete pvc runner-data-edge-runner-0
  ```

## Values reference

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Number of runner replicas |
| `runner.orgId` | `YOUR-ORG-ID-HERE` | CloudBees Unify organisation ID |
| `runner.name` | `runner` | Runner name prefix (registers as `<name>-<index>`) |
| `runner.labels` | `self-hosted` | Comma-separated runner labels |
| `runner.pat` | `""` | PAT — if set, chart creates the secret automatically |
| `runner.workingDir` | `/opt/runner` | Runner working directory (on PVC) |
| `image.repository` | `ubuntu` | Container image |
| `image.tag` | `22.04` | Container image tag |
| `binaryUrl` | `(placeholder)` | URL to download the runner binary |
| `kubeconfig.enabled` | `false` | Mount a kubeconfig secret |
| `ssh.enabled` | `false` | Mount SSH key secret |
| `toolsInit.enabled` | `false` | Enable tools init container extension point |
| `storage.size` | `1Gi` | PVC size per replica |

Full values documentation is in `charts/unify-edge-runner/values.yaml`.

## Security

Never commit PATs, tokens, or credentials to values files. Always pass sensitive values via `--set` at install time or use a secrets manager.
