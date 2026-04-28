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

          echo 'export PATH="/c/Program Files/GitHub CLI:$PATH"' >> ~/.bashrc
          source ~/.bashrc

11. # Inspect what bootstrap actually created on disk
          cd $HOME 
          gh repo clone 7ganeshs/ericson-infra 
          cd ericson-infra 
          ls clusters/lab/flux-system/
          
          # On disk (where you ran the command):
          ls ericson-infra/clusters/lab/flux-system/

12. # deploy GitOps workload — podinfo. Create a GitRepository pointing at the upstream podinfo repo

          cd ericson-infra
          flux create source git podinfo \
            --url=https://github.com/stefanprodan/podinfo \
            --branch=master \
            --interval=1m \
            --export > ./clusters/lab/podinfo-source.yaml
           
          cat ./clusters/lab/podinfo-source.yaml

13. # Create a Kustomization pointing at podinfo's deploy/kustomize directory

         flux create kustomization podinfo \
            --target-namespace=default \
            --source=podinfo \
            --path="./kustomize" \
            --prune=true \
            --interval=5m \
            --health-check-timeout=2m \
            --export > ./clusters/lab/podinfo-kustomization.yaml
           
          cat ./clusters/lab/podinfo-kustomization.yaml

14. # Commit and push. The git push IS the deployment.
          git add ./clusters/lab/podinfo-source.yaml ./clusters/lab/podinfo-kustomization.yaml
          git commit -m "Add podinfo source and kustomization"
          git push origin main


15. # Watch Flux reconcile
         flux get all

16. # workspace list
         kubectl get all -n default

17. # BIGGER DRIFT — delete the entire Deployment.
          kubectl delete deployment podinfo
          kubectl get deployment 
          
          kubectl get deployment

18. # Drift correction demo

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

19. # Flux reconcile command
          flux reconcile kustomization podinfo

    ============

    # DAY 2

1. Recreat the Kind cluster
        
     # Delete the cluster from docker desktop
     # then run the below command
          kind create cluster --name flux-lab --image kindest/node:v1.32.0
     
          kubectl get nodes
     
          export GITHUB_USER=$(gh api user -q .login)

          flux bootstrap github \
            --owner=$GITHUB_USER \
            --repository=ericson-infra-d2 \
            --branch=main \
            --path=clusters/lab \
            --personal \
            --private \
            --token-auth

             11  flux get kustomizations
             12  gh repo clone $GITHUB_USER/ericson-infra-d2
             13  cd ericson-infra
             14  cd ../ericson-infra-d2/
             15  ls -lart
             16  ls -lart clusters/
             17  ls -lart clusters/lab/
             18  ls -lart clusters/lab/flux-system/
             19  history

   
               
                  20  mkdir -p apps/base/podinfo
                  21  cat > apps/base/podinfo/deployment.yaml <<'EOF'
               ---
               apiVersion: apps/v1
               kind: Deployment
               metadata:
                 name: podinfo
                 labels:
                   app: podinfo
               spec:
                 replicas: 1
                 selector:
                   matchLabels:
                     app: podinfo
                 template:
                   metadata:
                     labels:
                       app: podinfo
                   spec:
                     containers:
                       - name: podinfo
                         image: ghcr.io/stefanprodan/podinfo:6.7.1
                         ports:
                           - name: http
                             containerPort: 9898
                         env:
                           - name: PODINFO_UI_COLOR
                             value: "#34577c"
                         livenessProbe:
                           httpGet:
                             path: /healthz
                             port: 9898
                           initialDelaySeconds: 5
                           periodSeconds: 10
                         readinessProbe:
                           httpGet:
                             path: /readyz
                             port: 9898
                           initialDelaySeconds: 5
                           periodSeconds: 10
                         resources:
                           requests:
                             cpu: 100m
                             memory: 64Mi
                           limits:
                             cpu: 500m
                             memory: 256Mi
               EOF
               
                  22  cat > apps/base/podinfo/service.yaml <<'EOF'
               ---
               apiVersion: v1
               kind: Service
               metadata:
                 name: podinfo
                 labels:
                   app: podinfo
               spec:
                 type: ClusterIP
                 selector:
                   app: podinfo
                 ports:
                   - name: http
                     port: 9898
                     targetPort: http
               EOF
               
                  23  ls apps/base/podinfo/
                  24  cat > apps/base/podinfo/kustomization.yaml <<'EOF'
               ---
               apiVersion: kustomize.config.k8s.io/v1beta1
               kind: Kustomization
               resources:
                 - deployment.yaml
                 - service.yaml
               EOF
               
                  25
                  26  ls apps/base/podinfo/
                  27  ll apps/base/podinfo/
                  28  mkdir -p apps/overlays/dev
                  29  ll /apps
                  30  ll apps
                  31  ll apps/overlays/
                  32  mkdir -p apps/overlays/staging
                  33  ll apps/overlays/
                  34  cat > apps/overlays/dev/namespace.yaml <<'EOF'
               ---
               apiVersion: v1
               kind: Namespace
               metadata:
                 name: dev
                 labels:
                   environment: dev
               EOF
               
                  35  cat > apps/overlays/dev/kustomization.yaml <<'EOF'
               ---
               apiVersion: kustomize.config.k8s.io/v1beta1
               kind: Kustomization
               namespace: dev
               commonLabels:
                 environment: dev
               resources:
                 - namespace.yaml
                 - ../../base/podinfo
               EOF
               
                  36
                  37  ls apps/overlays/dev
                  38  ll apps/overlays/dev
                  39  ll apps/overlays/dev apps/overlays/staging/
                  40  ll apps/base/podinfo/ apps/overlays/dev apps/overlays/staging/
                  41  cat > apps/overlays/staging/namespace.yaml <<'EOF'
               ---
               apiVersion: v1
               kind: Namespace
               metadata:
                 name: staging
                 labels:
                   environment: staging
               EOF
               
                  42  cat > apps/overlays/staging/kustomization.yaml <<'EOF'
               ---
               apiVersion: kustomize.config.k8s.io/v1beta1
               kind: Kustomization
               namespace: staging
               commonLabels:
                 environment: staging
               resources:
                 - namespace.yaml
                 - ../../base/podinfo
               patches:
                 - target:
                     kind: Deployment
                     name: podinfo
                   patch: |
                     - op: replace
                       path: /spec/replicas
                       value: 2
                     - op: replace
                       path: /spec/template/spec/containers/0/env/0/value
                       value: "#f5a623"
               EOF
               
                  43  ls -l clusters/lab/flux-system/ apps/base/ apps/base/podinfo/ apps/overlays/dev/ apps/overlays/staging/
                  44  ls -l clusters/lab/flux-system/ apps/base/ apps/base/podinfo/ apps/overlays/dev/ apps/overlays/staging/ clusters/lab/
                  45  cat clusters/lab/flux-system/kustomization.yaml
                  46  cat > clusters/lab/apps-dev.yaml <<'EOF'
               ---
               apiVersion: kustomize.toolkit.fluxcd.io/v1
               kind: Kustomization
               metadata:
                 name: apps-dev
                 namespace: flux-system
               spec:
                 interval: 5m
                 retryInterval: 1m
                 timeout: 3m
                 sourceRef:
                   kind: GitRepository
                   name: flux-system
                 path: ./apps/overlays/dev
                 prune: true
                 wait: true
               EOF
               
                  47  cat > clusters/lab/apps-staging.yaml <<'EOF'
               ---
               apiVersion: kustomize.toolkit.fluxcd.io/v1
               kind: Kustomization
               metadata:
                 name: apps-staging
                 namespace: flux-system
               spec:
                 interval: 5m
                 retryInterval: 1m
                 timeout: 3m
                 sourceRef:
                   kind: GitRepository
                   name: flux-system
                 path: ./apps/overlays/staging
                 prune: true
                 wait: true
               EOF
               
                  48  ls clusters/lab/
                  49  ll clusters/lab/
                  50  git add .
                  51  git commit -m "add podinfo base, dev and staging overlays"
                  52  git push
                  53  flux get all
                  54  kubectl get ns
                  55  flux reconcile source git flux-system
                  56  flux get all
                  57  flux get all
                  58  flux reconcile kustomization flux-system
                  59  flux get all
                  60  kubectl get ns
                  61  kubectl get deployments -n dev
                  62  kubectl get deployments -n stagine
                  63  kubectl get deployments -n staging
                  64  kubectl get all -n dev
                  65  kubectl get all -n staging
                  66  kubectl -n dev port-forward svc/podinfo 9001:9898
                  67  kubectl -n staging port-forward svc/podinfo 9002:9898
                  68  history





