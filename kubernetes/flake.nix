{
  description = "Kubernetes development environment with AWS EKS access";
  
  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
  {
    self,
    nixpkgs,
    nixpkgs-unstable,
    systems,
  }:
  let
    forEachSystem =
      f: nixpkgs.lib.genAttrs (import systems) (system: f {
        inherit system;
        pkgs = import nixpkgs { inherit system; };
        pkgs-unstable = import nixpkgs-unstable { inherit system; };
      });
  in
  {
    devShells = forEachSystem (
      { pkgs, pkgs-unstable, system }:
      let
        # AWS Credentials Configuration
        # Customize these values when entering the shell
        awsAccessKeyId = builtins.getEnv "AWS_ACCESS_KEY_ID";
        awsSecretAccessKey = builtins.getEnv "AWS_SECRET_ACCESS_KEY";
        awsSessionToken = builtins.getEnv "AWS_SESSION_TOKEN";
        
        # Session token validity duration in seconds (default: 60)
        # Adjust this to match your actual token expiry time
        tokenValidityDuration = "60";
        
        # Core packages for Kubernetes and AWS
        corePackages = with pkgs; [
          kubectl
          kubernetes-helm
          k9s
          awscli2
          aws-iam-authenticator
        ];
        
        # Additional utility packages (easily extensible)
        utilityPackages = with pkgs; [
          jq
          yq-go
          curl
          wget
          git
        ];
        
        # Combine all packages
        myPackages = corePackages ++ utilityPackages;
        
        # Generate space-delimited list of package names
        packageNames = builtins.concatStringsSep " " (map (p: p.pname or p.name) myPackages);
        
        # Script to check AWS token validity
        checkTokenScript = pkgs.writeShellScriptBin "check-aws-token" ''
          if [ -z "$AWS_SESSION_TOKEN" ]; then
            echo "❌ No AWS session token found in environment"
            exit 1
          fi
          
          echo "🔍 Checking AWS credentials validity..."
          if aws sts get-caller-identity &>/dev/null; then
            echo "✅ AWS credentials are valid"
            
            # Try to extract expiration from token (this is approximate)
            echo "ℹ️  Session token was configured for ${tokenValidityDuration}s validity"
            echo "ℹ️  Use 'aws sts get-caller-identity' to verify access"
          else
            echo "❌ AWS credentials are invalid or expired"
            echo "💡 Tip: Exit and re-enter the shell with fresh credentials"
            exit 1
          fi
        '';
        
      in
      {
        default = pkgs.mkShellNoCC {
          packages = myPackages ++ [ checkTokenScript ];
          
          shellHook = ''
            # Configure AWS credentials
            export AWS_CONFIG_DIR="''${HOME}/.aws"
            mkdir -p "''${AWS_CONFIG_DIR}"
            
            # Prompt for credentials if not provided
            AWS_ACCESS_KEY_ID="${awsAccessKeyId}"
            AWS_SECRET_ACCESS_KEY="${awsSecretAccessKey}"
            AWS_SESSION_TOKEN="${awsSessionToken}"
            
            if [ -z "$AWS_ACCESS_KEY_ID" ]; then
              read -p "🔑 Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
            fi
            
            if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
              read -sp "🔐 Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
              echo
            fi
            
            if [ -z "$AWS_SESSION_TOKEN" ]; then
              read -sp "🎫 Enter AWS Session Token: " AWS_SESSION_TOKEN
              echo
            fi
            
            # Validate all credentials are provided
            if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ] && [ -n "$AWS_SESSION_TOKEN" ]; then
              cat > "''${AWS_CONFIG_DIR}/credentials" <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
aws_session_token = $AWS_SESSION_TOKEN
EOF
              chmod 600 "''${AWS_CONFIG_DIR}/credentials"
              
              # Export for use in current shell
              export AWS_ACCESS_KEY_ID
              export AWS_SECRET_ACCESS_KEY
              export AWS_SESSION_TOKEN
              
              echo "✅ AWS credentials configured successfully"
              echo "⏱️  Token validity: ${tokenValidityDuration} seconds from configuration time"
            else
              echo "❌ AWS credentials incomplete. Please provide all three values."
              echo "💡 You can also set them as environment variables before running 'nix develop':"
              echo "  export AWS_ACCESS_KEY_ID='your-key-id'"
              echo "  export AWS_SECRET_ACCESS_KEY='your-secret-key'"
              echo "  export AWS_SESSION_TOKEN='your-session-token'"
            fi
            
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🚀 Kubernetes + AWS Development Environment"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📦 System: ${system}"
            echo "📦 Packages: ${packageNames}"
            echo ""
            echo "🔧 Useful Commands:"
            echo "  k9s                      - Terminal UI for Kubernetes"
            echo "  kubectl get nodes        - List cluster nodes"
            echo "  kubectl get pods -A      - List all pods in all namespaces"
            echo "  helm list -A             - List all Helm releases"
            echo "  check-aws-token          - Verify AWS credentials validity"
            echo "  aws sts get-caller-identity - Show current AWS identity"
            echo "  aws eks list-clusters    - List available EKS clusters"
            echo ""
            echo "💡 Quick Start:"
            echo "  1. Update kubeconfig: aws eks update-kubeconfig --name <cluster-name> --region <region>"
            echo "  2. Verify connection: kubectl cluster-info"
            echo "  3. Launch k9s: k9s"
            echo ""
            echo "⚙️  Configuration:"
            echo "  • Token validity: ${tokenValidityDuration}s (customizable in flake.nix)"
            echo "  • AWS credentials: ~/.aws/credentials"
            echo "  • Add packages from pkgs or pkgs-unstable in flake.nix"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
          '';
        };
      }
    );
  };
}
