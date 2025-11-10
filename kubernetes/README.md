# Kubernetes + AWS EKS Development Environment

A Nix flake template for Kubernetes development with AWS EKS cluster access using temporary session tokens.

## Features

- **AWS Session Token Support**: Configure temporary AWS credentials (Access Key ID, Secret Access Key, Session Token)
- **Kubernetes Tools**: kubectl, helm, k9s, and AWS IAM authenticator
- **Token Validity Check**: Built-in command to verify AWS credentials
- **Dual Package Sources**: Access both stable (25.05) and unstable nixpkgs
- **Extensible**: Easy to add more packages from either repository
- **Helpful Shell Hook**: Displays useful commands and quick start guide

## Quick Start

### Option 1: Pre-export environment variables (recommended for scripts)

1. **Set your AWS credentials as environment variables:**

```bash
export AWS_ACCESS_KEY_ID='your-access-key-id'
export AWS_SECRET_ACCESS_KEY='your-secret-access-key'
export AWS_SESSION_TOKEN='your-session-token'
```

2. **Enter the development environment:**

```bash
nix develop
```

### Option 2: Interactive prompts

Simply run `nix develop` and you'll be prompted to enter your credentials interactively:

```bash
nix develop
# You'll be prompted:
# 🔑 Enter AWS Access Key ID: 
# 🔐 Enter AWS Secret Access Key: 
# 🎫 Enter AWS Session Token:
```

### Continue with setup

3. **Configure kubectl for your EKS cluster:**

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

4. **Launch k9s to explore your cluster:**

```bash
k9s
```

## Usage Modes

The template supports two ways to provide credentials:

1. **Environment Variables** (best for automation/scripts): Export the three AWS variables before running `nix develop`
2. **Interactive Prompts** (best for manual use): Just run `nix develop` and enter credentials when prompted

The Secret Access Key and Session Token prompts use silent input (won't display as you type) for security.

## Customization

### Change Token Validity Duration

Edit the `tokenValidityDuration` variable in `flake.nix` (default: 60 seconds):

```nix
tokenValidityDuration = "3600";  # 1 hour
```

### Add More Packages

Edit the package lists in `flake.nix`:

```nix
# From stable nixpkgs (25.05)
corePackages = with pkgs; [
  kubectl
  kubernetes-helm
  k9s
  awscli2
  aws-iam-authenticator
  # Add your packages here
];

# From unstable nixpkgs
utilityPackages = with pkgs-unstable; [
  # Add cutting-edge packages here
];
```

### Available Package Sources

- `pkgs` - NixOS 25.05 (stable)
- `pkgs-unstable` - nixpkgs HEAD (latest packages)

## Included Tools

**Kubernetes:**
- `kubectl` - Kubernetes command-line tool
- `helm` - Kubernetes package manager
- `k9s` - Terminal UI for Kubernetes

**AWS:**
- `awscli2` - AWS command-line interface
- `aws-iam-authenticator` - AWS IAM authentication for Kubernetes

**Utilities:**
- `jq` - JSON processor
- `yq-go` - YAML processor
- `curl` - Transfer data with URLs
- `wget` - Network downloader
- `git` - Version control

**Custom:**
- `check-aws-token` - Verify AWS credentials validity

## Useful Commands

```bash
# Check AWS credentials
check-aws-token
aws sts get-caller-identity

# List EKS clusters
aws eks list-clusters

# Configure kubectl
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Kubernetes operations
kubectl get nodes
kubectl get pods -A
kubectl cluster-info

# Helm operations
helm list -A

# Launch k9s
k9s
```

## Notes

- AWS credentials are written to `~/.aws/credentials`
- Session tokens are temporary and will expire after the configured duration
- Re-enter the shell with fresh credentials when tokens expire
- The template uses Nix 25.05 as the base with unstable available for newer packages
