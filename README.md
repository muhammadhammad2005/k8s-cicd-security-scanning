# k8s-cicd-security-scanning

A production-ready DevSecOps lab demonstrating how to integrate static security analysis, container image scanning, and compliance enforcement directly into a Kubernetes CI/CD pipeline — using **Kubesec**, **KubeLinter**, and **Trivy**.

---

## 📌 What This Repo Does

This repository shows how to **shift security left** — catching misconfigurations and vulnerabilities at the code/manifest level *before* anything is deployed to Kubernetes. It answers the question:

> *"How do I make security automatic and enforced, not manual and optional?"*

### Core Activities

| Activity | Tool | Purpose |
|---|---|---|
| Kubernetes manifest analysis | Kubesec | Scores YAML files for security risks |
| Manifest linting | KubeLinter | Catches policy violations and bad practices |
| Container image scanning | Trivy | Finds known CVEs in images |
| CI/CD security gate | GitHub Actions | Blocks insecure code from merging |
| Policy enforcement | OPA Gatekeeper | Restricts images to trusted registries |

---

## 📁 Repository Structure

```
k8s-cicd-security-scanning/
├── app/                          # Sample Node.js application
│   ├── Dockerfile                # Hardened multi-stage Dockerfile
│   ├── .dockerignore
│   ├── package.json
│   └── src/
│       └── server.js             # Express server with health endpoint
│
├── manifests/                    # Kubernetes YAML files
│   ├── vulnerable-app.yaml       # Intentionally insecure deployment (for demo)
│   ├── secure-app.yaml           # Hardened deployment (best practices applied)
│   └── network-policy.yaml       # Default-deny network policy
│
├── policies/                     # Security policies
│   ├── kubelinter-config.yaml    # Custom KubeLinter rules
│   ├── allowed-registries.yaml   # Trusted image registries ConfigMap
│   ├── image-policy-template.yaml  # OPA Gatekeeper ConstraintTemplate
│   └── image-policy-constraint.yaml # OPA Gatekeeper Constraint
│
├── scripts/                      # Automation scripts
│   ├── ci-cd-pipeline.sh         # Full local pipeline simulation
│   ├── kubesec-scan.sh           # Kubesec batch scanner
│   ├── kubelinter-scan.sh        # KubeLinter batch scanner
│   └── image-scan.sh             # Trivy image scanner
│
├── reports/                      # Scan output (generated at runtime)
├── .github/
│   └── workflows/
│       └── security-scan.yml     # GitHub Actions CI/CD pipeline
├── .gitignore
└── README.md
```

---

## 🔐 Security Concepts Demonstrated

### 1. Vulnerable vs Secure Deployments

The repo includes two deployments side by side so you can see the difference:

**`vulnerable-app.yaml` — what NOT to do:**
- Runs as root (`runAsUser: 0`)
- Privileged container (`privileged: true`)
- Allows privilege escalation
- Hardcoded secrets in environment variables
- No resource limits
- Outdated image (`nginx:1.14`)
- Exposed via NodePort/LoadBalancer

**`secure-app.yaml` — what to do:**
- Non-root user (`runAsUser: 1000`)
- Read-only root filesystem
- All Linux capabilities dropped
- Secrets pulled from Kubernetes Secrets
- CPU and memory limits defined
- Liveness and readiness probes configured
- Up-to-date minimal image (`nginx:1.21-alpine`)
- Internal ClusterIP only

### 2. Kubesec Scoring

Kubesec assigns a security score to each manifest. Negative = dangerous. The vulnerable app scores negatively; the secure app scores positively.

### 3. KubeLinter Policy Checks

KubeLinter checks for violations like missing probes, missing resource limits, running as root, writable root filesystems, and more — based on a configurable ruleset in `policies/kubelinter-config.yaml`.

### 4. Trivy Image CVE Scanning

Trivy pulls the image and checks every package against the CVE database. `nginx:1.14` has hundreds of known vulnerabilities. `nginx:1.21-alpine` has significantly fewer.

### 5. The Security Gate

The CI/CD pipeline enforces rules:
- Negative Kubesec score → **pipeline fails**
- More than 10 high/critical CVEs → **pipeline fails**
- KubeLinter violations → **warning flagged**

---

## 🛠️ Prerequisites

| Tool | Version | Install |
|---|---|---|
| Docker | 20.x+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| Minikube | 1.30+ | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/docs/start/) |
| kubectl | 1.26+ | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools/) |
| Kubesec | latest | See setup below |
| KubeLinter | 0.6.8 | See setup below |
| Trivy | latest | See setup below |
| jq | any | `sudo apt-get install jq` |

---

## 🚀 Quick Start

### Step 1 — Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/k8s-cicd-security-scanning.git
cd k8s-cicd-security-scanning
```

### Step 2 — Start Minikube

```bash
minikube start
kubectl get nodes
```

### Step 3 — Install scanning tools

```bash
# Kubesec
curl -sSX GET https://api.github.com/repos/controlplaneio/kubesec/releases/latest \
  | grep browser_download_url \
  | grep linux-amd64 \
  | cut -d '"' -f 4 \
  | xargs curl -sSL -o kubesec
chmod +x kubesec && sudo mv kubesec /usr/local/bin/

# KubeLinter
curl -L https://github.com/stackrox/kube-linter/releases/download/0.6.8/kube-linter-linux.tar.gz \
  | tar xz
sudo mv kube-linter /usr/local/bin/

# Trivy
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
  | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install trivy -y

# jq
sudo apt-get install jq -y
```

### Step 4 — Run the full security pipeline

```bash
chmod +x scripts/*.sh
./scripts/ci-cd-pipeline.sh
```

This runs all three stages locally:
1. Kubesec manifest scoring
2. KubeLinter policy linting
3. Trivy image CVE scanning

Reports are saved to `reports/`.

---

## 🔬 Running Individual Scans

### Kubesec — score a manifest

```bash
# Scan a single file
kubesec scan manifests/vulnerable-app.yaml

# Scan all manifests and save reports
./scripts/kubesec-scan.sh
```

### KubeLinter — lint all manifests

```bash
# Quick lint
kube-linter lint manifests/

# Full scan with reports in all formats
./scripts/kubelinter-scan.sh
```

### Trivy — scan container images

```bash
# Scan a single image
trivy image nginx:1.14

# Scan all images referenced in manifests
./scripts/image-scan.sh
```

---

## 🐳 Building and Scanning the Custom App

The `app/` directory contains a hardened Node.js application with a production-grade multi-stage Dockerfile.

### Build the image locally with Minikube

```bash
# Point Docker to Minikube's daemon so the image is available in-cluster
eval $(minikube docker-env)

# Build the image
docker build -t secure-demo-app:1.0.0 ./app

# Scan the custom image with Trivy
trivy image secure-demo-app:1.0.0
```

### Deploy to Minikube

```bash
kubectl apply -f manifests/secure-app.yaml
kubectl apply -f manifests/network-policy.yaml
kubectl get pods
```

---

## 📊 Understanding the Reports

After running scans, check the `reports/` directory:

| Report file | Tool | What it shows |
|---|---|---|
| `kubesec-vulnerable-app.json` | Kubesec | Score + critical/advise breakdown |
| `kubesec-secure-app.json` | Kubesec | Comparison score |
| `kubelinter-full.json` | KubeLinter | All issues with object names |
| `kubelinter-summary.txt` | KubeLinter | Human-readable summary |
| `trivy-nginx_1_14.json` | Trivy | CVEs in nginx:1.14 |
| `trivy-nginx_1_21_alpine.json` | Trivy | CVEs in nginx:1.21-alpine |

### Compare Kubesec scores

```bash
echo "Vulnerable app score:"
cat reports/kubesec-vulnerable-app.json | jq '.[0].score'

echo "Secure app score:"
cat reports/kubesec-secure-app.json | jq '.[0].score'
```

### Count critical CVEs

```bash
echo "nginx:1.14 critical CVEs:"
cat reports/trivy-nginx_1_14.json | \
  jq '[.Results[]?.Vulnerabilities // [] | .[] | select(.Severity == "CRITICAL")] | length'

echo "nginx:1.21-alpine critical CVEs:"
cat reports/trivy-nginx_1_21_alpine.json | \
  jq '[.Results[]?.Vulnerabilities // [] | .[] | select(.Severity == "CRITICAL")] | length'
```

---

## ⚙️ GitHub Actions CI/CD Pipeline

The pipeline at `.github/workflows/security-scan.yml` runs automatically on every push to `main` or `develop`, and on every pull request to `main`.

### Pipeline stages

```
Push / PR
    │
    ▼
Stage 1: Install Tools (Kubesec, KubeLinter, Trivy)
    │
    ▼
Stage 2: Kubesec — score all manifests
    │  negative score → FAIL ❌
    ▼
Stage 3: KubeLinter — lint all manifests
    │  violations → WARNING ⚠️
    ▼
Stage 4: Trivy — scan all images
    │  >10 high/critical CVEs → FAIL ❌
    ▼
Stage 5: Upload reports as artifacts
    │
    ▼
Stage 6: Final security gate
    │  any failure above → block merge ❌
    ▼
   PASS ✅ — safe to deploy
```

### To use with your own GitHub repo

1. Push this repo to GitHub
2. The workflow triggers automatically on push
3. Go to **Actions** tab to see results
4. Reports are uploaded as downloadable artifacts (retained 30 days)

No secrets or tokens needed — all tools are installed fresh in each run.

---

## 🛡️ OPA Gatekeeper Policy (Advanced)

The `policies/` directory includes OPA Gatekeeper templates to enforce image registry restrictions at the Kubernetes admission level — meaning Kubernetes itself will **reject** deployments that use images from untrusted registries.

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
# This should be REJECTED (untrusted registry)
kubectl run test --image=untrusted-registry.com/myapp:latest

# This should be ALLOWED
kubectl run test --image=docker.io/nginx:1.21-alpine
```

---

## 🔑 Key Security Best Practices Applied

- ✅ Non-root container user
- ✅ Read-only root filesystem
- ✅ All Linux capabilities dropped
- ✅ No privilege escalation
- ✅ Resource requests and limits defined
- ✅ Liveness and readiness probes
- ✅ Secrets from Kubernetes Secrets, not env vars
- ✅ Minimal base image (Alpine)
- ✅ Multi-stage Docker build
- ✅ Default-deny NetworkPolicy
- ✅ Trusted image registry enforcement
- ✅ Automated CVE scanning in CI/CD
- ✅ Security gate blocking bad code from merging

---

## 📚 Tools Reference

| Tool | Docs |
|---|---|
| Kubesec | https://kubesec.io |
| KubeLinter | https://docs.kubelinter.io |
| Trivy | https://aquasecurity.github.io/trivy |
| OPA Gatekeeper | https://open-policy-agent.github.io/gatekeeper |
| Minikube | https://minikube.sigs.k8s.io |

---

## 📄 License

MIT — free to use, modify, and distribute.
