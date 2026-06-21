# unify-edge-runner

Helm chart for deploying CloudBees Unify Edge Runners as a Kubernetes StatefulSet.

Secrets are managed outside the chart. The chart references pre-created Kubernetes Secrets by name — it never generates or stores sensitive values.

## Prerequisites

- Kubernetes 1.21+
- Helm 3
- A CloudBees Unify organisation ID and a PAT with edge runner permissions

## Step 1: Create the namespace and required secrets

```bash
kubectl create namespace edge-runners

# Required: PAT for runner registration
kubectl create secret generic edge-runner-pat \
  --namespace edge-runners \
  --from-literal=pat='<YOUR_PAT>'
```

### Optional: kubeconfig (for jobs that use kubectl / helm)

```bash
kubectl create secret generic edge-runner-kubeconfig \
  --namespace edge-runners \
  --from-file=config=/path/to/kubeconfig
```

### Optional: SSH keys (for jobs that clone private Git repositories)

```bash
kubectl create secret generic edge-runner-ssh \
  --namespace edge-runners \
  --from-file=id_rsa=/path/to/private_key \
  --from-file=known_hosts=/path/to/known_hosts
```

## Step 2: Install the chart

```bash
helm repo add unify-edge-runner https://stubrowncloudbees.github.io/unify-edge-runner
helm repo update

helm install my-runners unify-edge-runner/unify-edge-runner \
  --namespace edge-runners \
  --set unify.orgId='YOUR-ORG-ID' \
  --set runner.name='k8s-home' \
  --set 'runner.labels=self-hosted\,k8s' \
  --set patSecret.name=edge-runner-pat
```

Each replica registers in Unify as `<name>-<index>` — e.g. `k8s-home-0`, `k8s-home-1`.

The runner binary is downloaded automatically at startup. The architecture (`amd64` or `arm64`) is detected at runtime — the same install command works on both x86 and ARM clusters.

The chart will fail with a clear error if `patSecret.name` is not provided.

### With optional mounts

```bash
helm install my-runners unify-edge-runner/unify-edge-runner \
  --namespace edge-runners \
  --set unify.orgId='YOUR-ORG-ID' \
  --set runner.name='k8s-home' \
  --set 'runner.labels=self-hosted\,k8s' \
  --set patSecret.name=edge-runner-pat \
  --set kubeconfig.enabled=true \
  --set kubeconfig.secretName=edge-runner-kubeconfig \
  --set ssh.enabled=true \
  --set ssh.secretName=edge-runner-ssh
```

## Scale

```bash
helm upgrade my-runners unify-edge-runner/unify-edge-runner \
  --reuse-values \
  --set replicaCount=3
```

Stale runner registrations and orphaned PVCs are cleaned up automatically after scale-down.

## Uninstall

```bash
helm uninstall my-runners --namespace edge-runners
```

On uninstall, a pre-delete hook deregisters all runners from Unify and deletes all PVCs — no manual cleanup required.

## Upgrade

```bash
helm repo update
helm upgrade my-runners unify-edge-runner/unify-edge-runner --reuse-values
```

## PAT rotation

```bash
kubectl create secret generic edge-runner-pat \
  --namespace edge-runners \
  --from-literal=pat='<NEW_PAT>' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart statefulset/my-runners-unify-edge-runner -n edge-runners
```

## Reconciler

The chart includes a reconciler that keeps Unify in sync with the StatefulSet replica count.

- **Hook Job** — runs automatically on every `helm install` and `helm upgrade`
- **CronJob** — runs every 15 minutes to catch drift

The reconciler detects stale runners (registered in Unify but no longer expected based on replica count), removes them from Unify, and deletes their PVCs. It only touches runners that match the configured `runner.name` prefix — other deployments are not affected.

To trigger a manual reconcile:

```bash
kubectl create job reconcile-now \
  --from=cronjob/my-runners-unify-edge-runner-reconciler \
  -n edge-runners
```

## Binary download URLs

The chart downloads the runner binary at container startup. The architecture is detected automatically. Official download URLs:

```
linux/amd64:   https://downloads.cloudbees.com/pub/unify-edge-runner/releases/main/linux/amd64/cloudbees-runner
linux/arm64:   https://downloads.cloudbees.com/pub/unify-edge-runner/releases/main/linux/arm64/cloudbees-runner
darwin/arm64:  https://downloads.cloudbees.com/pub/unify-edge-runner/releases/main/darwin/arm64/cloudbees-runner
windows/amd64: https://downloads.cloudbees.com/pub/unify-edge-runner/releases/main/windows/amd64/cloudbees-runner
```

## Known limitations

- Tools (apt, kubectl, helm) are installed at container startup. This adds latency and requires external network access. A pre-built image would eliminate this.
- Runners with an active job cannot be deregistered during scale-down or uninstall. They will be retried by the next reconciler run once the job completes.

## Values reference

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Number of runner replicas |
| `unify.apiUrl` | `https://api.cloudbees.io` | CloudBees Unify API base URL |
| `unify.orgId` | `YOUR-ORG-ID-HERE` | CloudBees Unify organisation ID |
| `runner.name` | `edge-runner` | Runner name prefix (registers as `<name>-<index>`) |
| `runner.labels` | `self-hosted` | Comma-separated runner labels |
| `runner.workingDir` | `/opt/runner` | Runner working directory (on PVC) |
| `patSecret.name` | `""` | **Required.** Name of the pre-created PAT secret |
| `patSecret.key` | `pat` | Key within the PAT secret |
| `image.repository` | `ubuntu` | Container image |
| `image.tag` | `22.04` | Container image tag |
| `binaryUrl` | `(auto)` | Override binary download URL. Use `{arch}` as a placeholder for automatic architecture substitution. |
| `kubeconfig.enabled` | `false` | Mount a kubeconfig secret |
| `kubeconfig.secretName` | `""` | Name of the pre-created kubeconfig secret |
| `ssh.enabled` | `false` | Mount SSH key secret |
| `ssh.secretName` | `""` | Name of the pre-created SSH secret |
| `toolsInit.enabled` | `false` | Enable tools init container extension point |
| `storage.size` | `1Gi` | PVC size per replica |
| `reconciler.enabled` | `true` | Enable the reconciler |
| `reconciler.mode` | `cleanup` | `audit` (log only) or `cleanup` (delete stale runners and PVCs) |
| `reconciler.cronJob.schedule` | `*/15 * * * *` | CronJob schedule |
| `reconciler.hookJob.enabled` | `true` | Run reconciler on every install/upgrade |

Full values documentation is in `charts/unify-edge-runner/values.yaml`.

## Security

All secrets (PAT, kubeconfig, SSH keys) must be pre-created as Kubernetes Secrets before installing the chart. The chart references them by name only — it never generates, stores, or renders sensitive values. Never commit real credentials to values files or the repository.
