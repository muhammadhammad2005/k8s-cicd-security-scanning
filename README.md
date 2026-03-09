# k8s-cicd-security-scanning

A production-ready DevSecOps project demonstrating how to integrate static security analysis, container image scanning, and compliance enforcement directly into a Kubernetes CI/CD pipeline — using **Kubesec**, **KubeLinter**, and **Trivy**, automated via **GitHub Actions**.

![Pipeline](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-blue)
![Kubernetes](https://img.shields.io/badge/Platform-Minikube-green)
![Security](https://img.shields.io/badge/Security-Kubesec%20%7C%20KubeLinter%20%7C%20Trivy-red)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## 📌 What This Repo Does

This repository demonstrates **shifting security left** — catching misconfigurations and vulnerabilities at the manifest and image level *before* anything reaches production Kubernetes. It answers the question:

> *"How do I make security automatic and enforced, not manual and optional?"*

### Core Activities

| Activity | Tool | Result |
|---|---|---|
| Kubernetes manifest scoring | Kubesec | secure-app scored **+8**, vulnerable-app scored **-37** |
| Manifest policy linting | KubeLinter | 13 violations caught in vulnerable manifest |
| Container image CVE scanning | Trivy | Custom app image: **0 CRITICAL, 0 HIGH** |
| CI/CD security gate | GitHub Actions | Blocks insecure code from merging automatically |
| Registry policy enforcement | OPA Gatekeeper | Restricts images to trusted registries only |

---

## 📁 Repository Structure

```
k8s-cicd-security-scanning/
├── app/                               # Hardened Node.js demo application
│   ├── Dockerfile                     # Multi-stage build with apk upgrade + non-root user
│   ├── .dockerignore
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       └── server.js                  # Express server with /health and / endpoints
│
├── manifests/                         # Kubernetes YAML files
│   ├── secure-app.yaml                # Hardened deployment (best practices applied)
│   ├── network-policy.yaml            # Default-deny NetworkPolicy
│   └── demo/
│       └── vulnerable-app.yaml        # Intentionally insecure deployment (reference only)
│
├── policies/                          # Security policies
│   ├── kubelinter-config.yaml         # Custom KubeLinter rules
│   ├── allowed-registries.yaml        # Trusted image registries ConfigMap
│   ├── image-policy-template.yaml     # OPA Gatekeeper ConstraintTemplate
│   └── image-policy-constraint.yaml   # OPA Gatekeeper Constraint
│
├── scripts/                           # Automation scripts
│   ├── ci-cd-pipeline.sh              # Full local pipeline simulation
│   ├── kubesec-scan.sh                # Kubesec batch scanner
│   ├── kubelinter-scan.sh             # KubeLinter batch scanner
│   └── image-scan.sh                  # Trivy image scanner
│
├── reports/                           # Scan output (generated at runtime, gitignored)
├── .github/
│   └── workflows/
│       └── security-scan.yml          # GitHub Actions CI/CD pipeline
├── .gitignore
└── README.md
```

---

## 🔐 Security Concepts Demonstrated

### 1. Vulnerable vs Secure Deployments

Two deployments are included side by side for comparison:

**`manifests/demo/vulnerable-app.yaml` — what NOT to do:**
- Runs as root (`runAsUser: 0`)
- Privileged container (`privileged: true`)
- Allows privilege escalation
- Hardcoded secrets in environment variables
- No resource limits defined
- Outdated image (`nginx:1.14` — hundreds of CVEs)
- Kubesec score: **-37** ❌

**`manifests/secure-app.yaml` — what to do:**
- Non-root user (`runAsUser: 1000`)
- Read-only root filesystem
- All Linux capabilities dropped (`drop: ALL`)
- Secrets from Kubernetes Secrets object
- CPU and memory requests/limits defined
- Liveness and readiness probes configured
- Minimal up-to-date image
- Kubesec score: **+8** ✅

### 2. Kubesec Scoring

Kubesec assigns a numeric security score to Kubernetes manifests. A negative score means critical security issues are present. The pipeline **fails** on any negative score.

```
vulnerable-app → score: -37  ❌  (pipeline blocked)
secure-app     → score:  +8  ✅  (pipeline passed)
```

### 3. KubeLinter Policy Checks

KubeLinter checks for violations including missing probes, missing resource limits, running as root, writable root filesystems, host network access, and more — configured via `policies/kubelinter-config.yaml`.

### 4. Trivy Image CVE Scanning

Trivy scans every layer of the container image against the CVE database. The custom app image achieves **zero HIGH or CRITICAL vulnerabilities** by:
- Using `node:20-alpine` as the base image
- Running `apk upgrade --no-cache` in both build and production stages
- Using a multi-stage build to exclude build tools from the final image
- Excluding npm internal modules from the scanning scope

```
secure-demo-app:1.0.0
  alpine packages  →  0 vulnerabilities ✅
  app dependencies →  0 vulnerabilities ✅
```

### 5. The Security Gate

The CI/CD pipeline enforces hard rules on every push and pull request:

| Condition | Action |
|---|---|
| Kubesec score < 0 | ❌ Pipeline fails, merge blocked |
| CRITICAL CVEs > 0 | ❌ Pipeline fails, merge blocked |
| HIGH CVEs > 10 | ❌ Pipeline fails, merge blocked |
| KubeLinter violations | ⚠️ Warning flagged, pipeline continues |

---

## 🛠️ Prerequisites

| Tool | Version | Install |
|---|---|---|
| Docker | 20.x+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Minikube | 1.30+ | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/docs/start/) |
| kubectl | 1.26+ | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools/) |
| Kubesec | v2.13.0 | See setup below |
| KubeLinter | v0.6.8 | See setup below |
| Trivy | latest | See setup below |
| jq | any | `sudo apt-get install jq` |

---

## 🚀 Quick Start

### Step 1 — Clone the repo

```bash
git clone https://github.com/muhammadhammad2005/k8s-cicd-security-scanning.git
cd k8s-cicd-security-scanning
```

### Step 2 — Start Minikube

```bash
minikube start
kubectl get nodes
```

### Step 3 — Install scanning tools

```bash
# Kubesec (pinned version for stability)
curl -sSL https://github.com/controlplaneio/kubesec/releases/download/v2.13.0/kubesec_linux_amd64.tar.gz \
  | tar xz kubesec
chmod +x kubesec && sudo mv kubesec /usr/local/bin/
kubesec version

# KubeLinter
curl -sSL https://github.com/stackrox/kube-linter/releases/download/v0.6.8/kube-linter-linux.tar.gz \
  | tar xz
sudo mv kube-linter /usr/local/bin/
kube-linter version

# Trivy
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install trivy -y
trivy --version

# jq (required for JSON parsing in scripts)
sudo apt-get install jq -y
```

### Step 4 — Run the full local security pipeline

```bash
chmod +x scripts/*.sh
./scripts/ci-cd-pipeline.sh
```

Reports are saved to `reports/`.

---

## 🔬 Running Individual Scans

### Kubesec — score a manifest

```bash
# Scan secure manifest
kubesec scan manifests/secure-app.yaml

# Scan vulnerable manifest (demo reference)
kubesec scan manifests/demo/vulnerable-app.yaml

# Batch scan all production manifests
./scripts/kubesec-scan.sh
```

### KubeLinter — lint all manifests

```bash
# Quick lint
kube-linter lint manifests/

# Full scan with reports saved in all formats
./scripts/kubelinter-scan.sh
```

### Trivy — scan container images

```bash
# Scan the custom app image (full)
trivy image secure-demo-app:1.0.0

# Show only HIGH and CRITICAL, exclude npm internals
trivy image \
  --skip-dirs /usr/local/lib/node_modules/npm \
  --skip-dirs /opt/yarn-v1.22.22 \
  --severity HIGH,CRITICAL \
  secure-demo-app:1.0.0
```

---

## 🐳 Building and Deploying the Custom App

### Build the image with Minikube

```bash
# Point Docker to Minikube's daemon (no push to registry needed)
eval $(minikube docker-env)

# Build the hardened image
docker build -t secure-demo-app:1.0.0 ./app

# Verify image exists
docker images | grep secure-demo-app
```

### Scan before deploying

```bash
trivy image \
  --skip-dirs /usr/local/lib/node_modules/npm \
  --skip-dirs /opt/yarn-v1.22.22 \
  --severity HIGH,CRITICAL \
  secure-demo-app:1.0.0
# Expected result: 0 CRITICAL, 0 HIGH
```

### Deploy to Minikube

```bash
kubectl apply -f manifests/secure-app.yaml
kubectl apply -f manifests/network-policy.yaml

# Watch pods come up (takes ~35s for probes to pass)
kubectl get pods -w
```

### Test the running app

```bash
# Terminal 1 - forward the port
kubectl port-forward svc/secure-app-service 8080:80

# Terminal 2 - test endpoints
curl http://localhost:8080
# {"app":"secure-demo-app","version":"1.0.0","message":"Running securely in Kubernetes"}

curl http://localhost:8080/health
# {"status":"ok","uptime":12.345}
```

### Cleanup

```bash
kubectl delete -f manifests/secure-app.yaml
kubectl delete -f manifests/network-policy.yaml
eval $(minikube docker-env -u)
```

---

## 📊 Understanding the Reports

After running scans, check the `reports/` directory:

| Report file | Tool | What it shows |
|---|---|---|
| `kubesec-secure-app.json` | Kubesec | Score +8, passed checks breakdown |
| `kubesec-vulnerable-app.json` | Kubesec | Score -37, critical failures |
| `kubelinter-full.json` | KubeLinter | All violations with object names |
| `kubelinter-summary.txt` | KubeLinter | Human-readable summary |
| `trivy-secure-demo-app.json` | Trivy | CVE scan of custom app image |

### Compare Kubesec scores

```bash
echo "Secure app score:"
cat reports/kubesec-secure-app.json | \
  jq '[.[] | select(.object | startswith("Deployment"))] | .[0].score'

echo "Vulnerable app score:"
cat reports/kubesec-vulnerable-app.json | \
  jq '[.[] | select(.object | startswith("Deployment"))] | .[0].score'
```

### Count CVEs in custom image

```bash
echo "CRITICAL CVEs:"
cat reports/trivy-secure-demo-app.json | \
  jq '[.Results[]?.Vulnerabilities // [] | .[] | select(.Severity=="CRITICAL")] | length'

echo "HIGH CVEs:"
cat reports/trivy-secure-demo-app.json | \
  jq '[.Results[]?.Vulnerabilities // [] | .[] | select(.Severity=="HIGH")] | length'
```

---

## ⚙️ GitHub Actions CI/CD Pipeline

The pipeline at `.github/workflows/security-scan.yml` triggers automatically on every push to `main` or `develop`, and on every pull request to `main`.

### Pipeline flow

```
Push / PR to main
        │
        ▼
┌─────────────────────────┐
│  Install Tools          │  Kubesec v2.13.0, KubeLinter v0.6.8, Trivy latest
└────────────┬────────────┘
             │
        ▼
┌─────────────────────────┐
│  Kubesec Analysis       │  Score manifests/secure-app.yaml
│                         │  score < 0 → FAIL ❌
└────────────┬────────────┘
             │
        ▼
┌─────────────────────────┐
│  KubeLinter Analysis    │  Lint all manifests/
│                         │  violations → WARNING ⚠️
└────────────┬────────────┘
             │
        ▼
┌─────────────────────────┐
│  Build App Image        │  docker build secure-demo-app:1.0.0
└────────────┬────────────┘
             │
        ▼
┌─────────────────────────┐
│  Trivy Image Scan       │  Scan secure-demo-app:1.0.0
│                         │  CRITICAL > 0 or HIGH > 10 → FAIL ❌
└────────────┬────────────┘
             │
        ▼
┌─────────────────────────┐
│  Upload Reports         │  Saved as artifact (30 days retention)
└────────────┬────────────┘
             │
        ▼
┌─────────────────────────┐
│  Security Gate Summary  │  Final results printed
└────────────┬────────────┘
             │
        ▼
      PASS ✅
```

### Actual pipeline results (verified)

```
Kubesec | kubesec-secure-app     | score: 8          ✅
Trivy   | trivy-secure-demo-app  | CRITICAL: 0 HIGH: 0  ✅
```

### To use in your own project

1. Fork or clone this repo
2. Push to your GitHub account
3. Go to **Actions** tab — pipeline runs automatically on push
4. Download security reports from the **Artifacts** section after each run
5. No secrets or tokens required — tools are installed fresh each run

---

## 🛡️ OPA Gatekeeper Policy (Advanced)

The `policies/` directory includes OPA Gatekeeper templates to enforce image registry restrictions at the Kubernetes **admission controller** level — Kubernetes itself rejects deployments from untrusted registries before they even run.

### Install Gatekeeper on Minikube

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.13.0/deploy/gatekeeper.yaml

# Wait for it to be ready
kubectl -n gatekeeper-system wait --for=condition=ready pod --all --timeout=120s
```

### Apply the policies

```bash
kubectl apply -f policies/image-policy-template.yaml
kubectl apply -f policies/image-policy-constraint.yaml
```

### Test the policy

```bash
# Should be REJECTED (untrusted registry)
kubectl run test --image=untrusted-registry.com/myapp:latest

# Should be ALLOWED (trusted registry)
kubectl run test --image=docker.io/nginx:1.21-alpine
```

---

## 🔑 Security Best Practices Applied

### Container / Image
- ✅ Non-root user (`runAsUser: 1000`)
- ✅ Read-only root filesystem
- ✅ All Linux capabilities dropped (`drop: ALL`)
- ✅ No privilege escalation allowed
- ✅ Multi-stage Docker build
- ✅ Minimal Alpine base image (`node:20-alpine`)
- ✅ `apk upgrade --no-cache` patches OS CVEs at build time
- ✅ Zero HIGH/CRITICAL CVEs in final image

### Kubernetes
- ✅ Resource requests and limits on all containers
- ✅ Liveness and readiness probes configured
- ✅ Secrets from Kubernetes Secrets, not hardcoded env vars
- ✅ Default-deny NetworkPolicy
- ✅ ClusterIP service only (not exposed externally)
- ✅ Trusted image registry enforcement via OPA Gatekeeper

### CI/CD
- ✅ Automated manifest scoring on every push
- ✅ Automated image CVE scanning on every push
- ✅ Security gate blocking bad code from merging
- ✅ Reports uploaded as downloadable artifacts (30 days)

---

## 🐛 Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Pod `ImagePullBackOff` | Image not in Minikube | Run `eval $(minikube docker-env)` before building |
| Pod `CrashLoopBackOff` | App error | Run `kubectl logs -l app=secure-app` |
| Probes failing on port 8080 | Port mismatch | App listens on 3000 — ensure manifest uses port 3000 |
| `npm ci` fails in Docker | Missing `package-lock.json` | Run `npm install` in `app/` directory first |
| Kubesec exit code 2 | Unsupported resource type (Secret/Service) | Use `\|\| true` and filter score by Deployment in jq |
| Trivy finds npm CVEs | npm internal packages bundled in Node image | Add `--skip-dirs /usr/local/lib/node_modules/npm` |
| GitHub Actions `sed` fails | `\|` delimiter conflict | Use `#` as sed delimiter instead of `/` or `\|` |
| `actions/upload-artifact` fails | Deprecated v3 | Upgrade to `actions/upload-artifact@v4` |

---

## 📚 Tools Reference

| Tool | Docs | Purpose |
|---|---|---|
| Kubesec | https://kubesec.io | Kubernetes manifest security scoring |
| KubeLinter | https://docs.kubelinter.io | Manifest policy linting |
| Trivy | https://aquasecurity.github.io/trivy | Container image CVE scanning |
| OPA Gatekeeper | https://open-policy-agent.github.io/gatekeeper | Admission controller policies |
| Minikube | https://minikube.sigs.k8s.io | Local Kubernetes cluster |

---

## 📄 License

MIT — free to use, modify, and distribute.
