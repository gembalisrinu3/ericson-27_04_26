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

          PS C:\Users\labuser> gh auth login
          ? Where do you use GitHub? GitHub.com
          ? What is your preferred protocol for Git operations on this host? HTTPS
          ? Authenticate Git with your GitHub credentials? Yes
          ? How would you like to authenticate GitHub CLI? Login with a web browser
          
          ! First copy your one-time code: B694-25AB
          Press Enter to open https://github.com/login/device in your browser...
          ✓ Authentication complete.
          - gh config set -h github.com git_protocol https
          ✓ Configured git protocol
        export GITHUB_USER=$(gh api user -q .login)

9. # Bootstrap Flux
        flux bootstrap github \
       --owner=$GITHUB_USER \
       --repository=ericson-infra \
       --branch=main \
       --path=clusters/lab \
       --personal \
       --private \
       --token-auth



       Get-ChildItem -Path "C:\Program Files" -Recurse -Filter gh.exe -ErrorAction SilentlyContinue
       Get-ChildItem -Path "$env:LOCALAPPDATA\Programs" -Recurse -Filter gh.exe -ErrorAction SilentlyContinue
       $env:Path += ";C:\Program Files\GitHub CLI"

10. # Inspect what bootstrap actually created on disk
          cd $HOME 
          gh repo clone 7ganeshs/ericson-infra 
          cd ericson-infra 
          ls clusters/lab/flux-system/
          
          # On disk (where you ran the command):
          ls ericson-infra/clusters/lab/flux-system/

11. # deploy GitOps workload — podinfo. Create a GitRepository pointing at the upstream podinfo repo

          cd ericson-infra
          flux create source git podinfo \
            --url=https://github.com/stefanprodan/podinfo \
            --branch=master \
            --interval=1m \
            --export > ./clusters/lab/podinfo-source.yaml
           
          cat ./clusters/lab/podinfo-source.yaml

12. # Create a Kustomization pointing at podinfo's deploy/kustomize directory

         flux create kustomization podinfo \
            --target-namespace=default \
            --source=podinfo \
            --path="./kustomize" \
            --prune=true \
            --interval=5m \
            --health-check-timeout=2m \
            --export > ./clusters/lab/podinfo-kustomization.yaml
           
          cat ./clusters/lab/podinfo-kustomization.yaml

13. # Commit and push. The git push IS the deployment.
          git add ./clusters/lab/podinfo-source.yaml ./clusters/lab/podinfo-kustomization.yaml
          git commit -m "Add podinfo source and kustomization"
          git push origin main


14. # Watch Flux reconcile
         flux get all

15. # workspace list
         kubectl get all -n default

16. # BIGGER DRIFT — delete the entire Deployment.
          kubectl delete deployment podinfo
          kubectl get deployment 
          
          kubectl get deployment

17. # Drift correction demo

          Confirm starting state - check current image tag.
          kubectl get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}'
          echo
          (whatever upstream's master has)
           
          Drift it. Manually change the image tag.
          kubectl set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.0
           
          Confirm the drift took effect.
          kubectl get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}'
          echo
          your manual change is live.
           
          Force Flux to reconcile NOW (instead of waiting 5 min interval).
          flux reconcile kustomization podinfo --with-source
           
          Verify Flux REVERTED the image tag back to Git's value.
          kubectl get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}'
          echo
          back to 6.x.x - Flux reverted your drift. Git won.

18. # Flux reconcile command
          flux reconcile kustomization podinfo

    ============

    # DAY 2

1. Recreat the Kind cluster
        
     Delete the cluster from docker desktop
     then run the below command
     kind create cluster --name flux-lab --image kindest/node:v1.32.0

     kubectl get nodes

     flux bootstrap github \
       --owner=$GITHUB_USER \
       --repository=ericson-infra-d2 \
       --branch=main \
       --path=clusters/lab \
       --personal \
       --private \
       --token-auth
     



