# unify-edge-runner

Production-quality Helm chart for deploying CloudBees Unify Edge Runners as a Kubernetes StatefulSet.

## Design Principles

| Principle | How it's implemented |
|-----------|---------------------|
| **Safe by default** | kubeconfig and SSH are disabled by default; must be explicitly opted in |
| **Idempotent** | Registration init container checks for existing `config.yaml` and skips if found |
| **Least privilege** | Secrets mounted read-only; no cluster-wide RBAC required by default |
| **Separation of concerns** | Registration (init) vs. runtime (main container) are clearly separated |
| **Extensibility** | `toolsInit` extension point injects tools via a shared `emptyDir` volume |
| **Stable identity** | StatefulSet gives each runner a stable pod name (`<release>-0`, `<release>-1`, ...) |
| **Persistence** | PVC per replica preserves registration config across restarts — prevents stale runner accumulation |

## Known Limitations

- **Tool installation at startup:** The main container currently installs tools (apt, kubectl, helm) at startup every time the pod starts. This adds latency and depends on external mirrors being reachable. A pre-built runner image would eliminate this. See [Future Work](#future-work).
- **ubuntu:22.04 base image:** Used as a convenient temporary base. Replace with a purpose-built image when available.
- **Binary download at registration:** The runner binary is downloaded in the init container on first registration. If the download URL is unavailable, registration fails and the pod enters `CrashLoopBackOff`.
- **No reconciliation:** Stale runner entries in Unify (orphaned by pod deletion without deregistration) are not automatically cleaned up. Planned as a future CronJob once the Unify deregistration API is confirmed.
- **PVC lifecycle:** PVCs created by `volumeClaimTemplates` are NOT deleted when the StatefulSet or Helm release is deleted. You must delete them manually if you want to force re-registration:
  ```bash
  kubectl delete pvc runner-data-<release>-0
  ```

## Prerequisites

1. Kubernetes cluster (1.21+)
2. Helm 3
3. A CloudBees Unify organisation and a PAT with edge runner permissions
4. Pre-created Kubernetes Secrets (see below)

## Required Secret

The PAT secret must exist before installing the chart:

```bash
kubectl create secret generic <release>-pat \
  --from-literal=pat='YOUR_PAT_HERE'
```

Replace `<release>` with your Helm release name (default: `edge-runner`).

## Optional Secrets

### Kubeconfig (enables kubectl/helm in jobs)

```bash
kubectl create secret generic <release>-kubeconfig \
  --from-file=config=/path/to/kubeconfig
```

Enable in values:
```yaml
kubeconfig:
  enabled: true
```

### SSH keys (enables SSH-based Git clone in jobs)

```bash
kubectl create secret generic <release>-ssh \
  --from-file=id_rsa=/path/to/private_key \
  --from-file=known_hosts=/path/to/known_hosts
```

Enable in values:
```yaml
ssh:
  enabled: true
```

## Installation

```bash
# Minimal install
helm install edge-runner ./charts/unify-edge-runner \
  --set runner.orgId='YOUR-ORG-ID' \
  --set runner.labels='self-hosted,k8s' \
  --set binaryUrl='https://downloads.example.com/cloudbees-runner/linux/amd64/cloudbees-runner'

# With kubeconfig and SSH enabled
helm install edge-runner ./charts/unify-edge-runner \
  --set runner.orgId='YOUR-ORG-ID' \
  --set runner.labels='self-hosted,k8s' \
  --set binaryUrl='https://...' \
  --set kubeconfig.enabled=true \
  --set ssh.enabled=true

# Scale to 3 replicas
helm upgrade edge-runner ./charts/unify-edge-runner \
  --reuse-values \
  --set replicaCount=3
```

## Upgrade

```bash
helm upgrade edge-runner ./charts/unify-edge-runner --reuse-values
```

## Verification

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/instance=edge-runner

# Check registration (init container logs)
kubectl logs edge-runner-0 -c register

# Check runner (main container logs)
kubectl logs -f edge-runner-0
```

## PAT Rotation

When the PAT expires:

```bash
# Update the secret
kubectl create secret generic edge-runner-pat \
  --from-literal=pat='YOUR_NEW_PAT' \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to trigger re-authentication
kubectl rollout restart statefulset/edge-runner
```

Note: re-registration is skipped if `config.yaml` already exists on the PVC. The PAT is only used at registration time. If runners continue working after PAT rotation without restart, that is expected — the registered token has its own validity period.

## Tools Init Container

To inject additional tools (e.g. a specific kubectl version, cloud CLIs):

```yaml
toolsInit:
  enabled: true
  image: ubuntu:22.04
  script: |
    mkdir -p /tools/bin
    curl -sL -o /tools/bin/kubectl \
      "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"
    chmod +x /tools/bin/kubectl
```

Tools placed in `/tools/bin` are automatically available to the main container via `PATH`.

## Values Reference

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Number of runner replicas |
| `runner.orgId` | `YOUR-ORG-ID-HERE` | CloudBees Unify organisation ID |
| `runner.labels` | `self-hosted` | Comma-separated runner labels |
| `runner.workingDir` | `/opt/runner` | Runner working directory (on PVC) |
| `image.repository` | `ubuntu` | Container image |
| `image.tag` | `22.04` | Container image tag |
| `binaryUrl` | `(placeholder)` | URL to download the runner binary |
| `patSecret.name` | `""` | PAT secret name (defaults to `<release>-pat`) |
| `kubeconfig.enabled` | `false` | Mount a kubeconfig secret |
| `ssh.enabled` | `false` | Mount SSH key secret |
| `toolsInit.enabled` | `false` | Enable tools init container |
| `storage.size` | `1Gi` | PVC size per replica |

Full documentation of all values is in `charts/unify-edge-runner/values.yaml`.

## Security Notes

- **Never commit** PATs, tokens, kubeconfig files, SSH keys, or any credentials to this repository.
- All sensitive values must be provided via pre-created Kubernetes Secrets or via `--set` at deploy time (not in values files committed to Git).
- If in doubt about whether something should be committed, do not commit it.

## Future Work

- Pre-built runner Docker image (eliminate apt-get at startup)
- Reconciliation CronJob to clean up stale runner entries in Unify (pending API confirmation)
- Optional ServiceAccount + RBAC for in-cluster kubectl access without mounting an admin kubeconfig
- Liveness/readiness probes once the runner binary exposes a health endpoint
