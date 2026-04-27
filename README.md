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
       Get-ChildItem -Path "C:\Program Files" -Recurse -Filter gh.exe -ErrorAction SilentlyContinue
       Get-ChildItem -Path "$env:LOCALAPPDATA\Programs" -Recurse -Filter gh.exe -ErrorAction SilentlyContinue
       $env:Path += ";C:\Program Files\GitHub CLI"
