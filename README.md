# ericson-27_04_26

1. Please make use of Personal Github User ID. If personal github user id not there, pls create it one.

2. # Install the software:
     # All four tools via Chocolatey (Run as adminstrator from Powershell)
        choco install -y kubernetes-cli kind flux gh git

     # Verify all Tools
       docker --version
       kind --version
       kubectl version --client
       flux --version
       gh --version
       git --version

4. # Kind cluster Install
       kind create cluster --name flux-lab --image kindest/node:v1.32.0

5. # context
        kubectl config current-context
        kubectl get nodes

6. # Flux pre-flight check.
        flux check --pre

7. # Github Cred
        gh auth login             
        export GITHUB_USER=$(gh api user -q .login)

8. # Bootstrap Flux
        flux bootstrap github \
       --owner=$GITHUB_USER \
       --repository=ericson-infra \
       --branch=main \
       --path=clusters/lab \
       --personal \
       --private



       Get-ChildItem -Path "C:\Program Files" -Recurse -Filter gh.exe -ErrorAction SilentlyContinue
       Get-ChildItem -Path "$env:LOCALAPPDATA\Programs" -Recurse -Filter gh.exe -ErrorAction SilentlyContinue
       $env:Path += ";C:\Program Files\GitHub CLI"
