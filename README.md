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
                            4  curl -s http://localhost:9001/api/info | grep -i color
                            5  curl -s http://localhost:9002/api/info | grep -i color

                  70  kubectl scale deployment podinfo -n dev --replicas=5
                  71  kubectl get deployments -n dev
                  72  kubectl get deployments -n dev
                  73  kubectl get deployments -n dev
                  74  kubectl get deployments -n dev
                  75  kubectl get deployments -n dev
                  76  kubectl get deployments -n dev
                  77  kubectl get deployments -n dev
                  78  flux reconcile kustomization apps-dev
                  79  kubectl get deployments -n dev
                  80  vi apps/overlays/staging/kustomization.yaml
                  81  cat apps/base/podinfo/deployment.yaml | grep -i image
                  82  vi apps/overlays/staging/kustomization.yaml
                  83  git add apps/overlays/staging/kustomization.yaml
                  84  git commit -m "demo: dummy image published to staging"
                  85  git push
                  86  flux reconcile kustomization apps-staging
                  87  vi apps/overlays/staging/kustomization.yaml
                  88  git add apps/overlays/staging/kustomization.yaml
                  89  git commit -m "demo: restore image published to staging"
                  90  git push
                  91  flux get all
                  92  flux reconcile kustomization apps-staging

                  65  kubectl get all -n staging
                  66  kubectl -n dev port-forward svc/podinfo 9001:9898
                  67  kubectl -n staging port-forward svc/podinfo 9002:9898
                  68  history


   # secret creation using SOPS
             cd ~/ericson-infra-d2
            4  age-keygen.exe -o demo.agekey
              5  cat demo.agekey
              6  cat demo.agekey  | grep -i public
              7  grep "public key" demo.agekey | sed 's/# public key: //'
              8  PUBKEY=$(grep "public key" demo.agekey | sed 's/# public key: //')
              9  echo $PUBKEY
             10  cat > .sops.yaml <<EOF
                    ---
                    creation_rules:
                      - path_regex: appsecret(\.enc)?\.yaml$
                        encrypted_regex: '^(data|stringData)$'
                        age: $PUBKEY
                    EOF

             11  cat .sops.yaml
             12  cat > apps/base/podinfo/appsecret.yaml <<'EOF'
                    ---
                    apiVersion: v1
                    kind: Secret
                    metadata:
                      name: podinfo-appsecret
                    type: Opaque
                    stringData:
                      api-token: "demo-token-1234567890"
                      db-password: "demo-password-secure"
                      smtp-host: "smtp.demo.example.com"
                    EOF

             13  sops --encrypt apps/base/podinfo/appsecret.yaml > apps/base/podinfo/appsecret.enc.yaml
             14  cat apps/base/podinfo/appsecret.enc.yaml
             15  export SOPS_AGE_KEY=$(cat demo.agekey | grep "AGE-SECTET-KEY")
             16  echo "key loaded: $(SOPS_AGE_KEY:0:30)..."
             17  cat demo.agekey | grep "AGE-SECTET-KEY"
             18  cat demo.agekey
             19  export SOPS_AGE_KEY=$(cat demo.agekey | grep "AGE-SECRET-KEY")
             20  echo "key loaded: $(SOPS_AGE_KEY:0:30)..."
             21  export SOPS_AGE_KEY=$(cat demo.agekey | grep "AGE-SECRET-KEY")
             22  $SOPS_AGE_KEY
             23  sops --decrypt apps/base/podinfo/appsecret.enc.yaml
             24  cat apps/base/podinfo/appsecret.enc.yaml
             25  kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey=demo.agekey
             26  kubectl get secret sops-age -n flux-system
             27  cd apps/base/podinfo
             28  ls
             29  cat appsecret.enc.yaml
             30  vi kustomization.yaml
                            labuser@server2022 MINGW64 ~/ericson-infra-d2/apps/base/podinfo (main)
                    $ cat kustomization.yaml
                    ---
                    apiVersion: kustomize.config.k8s.io/v1beta1
                    kind: Kustomization
                    resources:
                      - deployment.yaml
                      - service.yaml
                      - appsecret.enc.yaml


             31  cd ../../..
             32  cd clusters/lab/apps-dev.yaml
             33  vi clusters/lab/apps-dev.yaml

                    labuser@server2022 MINGW64 ~/ericson-infra-d2 (main)
                    $ cat clusters/lab/apps-dev.yaml
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
                      decryption:
                        provider: sops
                        secretRef:
                          name: sops-age

   
             34  cat apps/base/podinfo/kustomization.yaml
             35  ls apps/base/podinfo/appsecret.enc.yaml
             36  ls apps/base/podinfo
             37  cat apps/base/podinfo/appsecret.yaml
             38  rm -f apps/base/podinfo/appsecret.yaml
             39  ls apps/base/podinfo
             40  cat apps/base/podinfo/secret-plain.yaml
             41  rm apps/base/podinfo/secret-plain.yaml
             42  rm apps/base/podinfo/secret.enc.yaml
             43  ls apps/base/podinfo
             44  cat apps/base/podinfo/kustomization.yaml
             45  git add .
             46  git commit -m "sops intergration"
             47  git push
             48  flux reconcile source git flux-system
             49  flux reconcile kustomization flux-system
             50  flux reconcile kustomization apps-dev
             51  flux get all
             52  kubectl get all -n dev
             53  kubectl get secret -n dev
             54  kubectl get secret podinfo-appsecret -n dev
             55  kubectl get secret podinfo-appsecret -n dev -o jsonpath='{.data.api-token}'
             56  kubectl get secret podinfo-appsecret -n dev -o jsonpath='{.data.api-token}' | base64 -d
             57  sops --decrypt apps/base/podinfo/appsecret.enc.yaml
             58  history

        # Image Update
              69  flux bootstrap github   --owner=7ganeshs   --repository=ericson-infra-d2   --branch=main   --path=clusters/lab   --personal   --private   --token-auth   --components-extra=image-reflector-controller,image-automation-controller
             70  kubectl get pods -n flux-system
             71  mkdir -p apps/overlays/dev/image-automation
             72  cd apps/overlays/dev/image-automation/
             73  ls
             74  cat > apps/overlays/dev/image-automation/image-repository.yaml <<'EOF'
          ---
          apiVersion: image.toolkit.fluxcd.io/v1beta2
          kind: ImageRepository
          metadata:
            name: podinfo
            namespace: flux-system
          spec:
            image: ghcr.io/stefanprodan/podinfo
            interval: 5m
          EOF
          
             75  cd -
             76  cat > apps/overlays/dev/image-automation/image-repository.yaml <<'EOF'
          ---
          apiVersion: image.toolkit.fluxcd.io/v1beta2
          kind: ImageRepository
          metadata:
            name: podinfo
            namespace: flux-system
          spec:
            image: ghcr.io/stefanprodan/podinfo
            interval: 5m
          EOF
          
             77  cat > apps/overlays/dev/image-automation/image-policy.yaml <<'EOF'
          ---
          apiVersion: image.toolkit.fluxcd.io/v1beta2
          kind: ImagePolicy
          metadata:
            name: podinfo
            namespace: flux-system
          spec:
            imageRepositoryRef:
              name: podinfo
            policy:
              semver:
                range: '>=6.7.0 <7.0.0'
          EOF
          
             78  cat > apps/overlays/dev/image-automation/image-update.yaml <<'EOF'
          ---
          apiVersion: image.toolkit.fluxcd.io/v1beta2
          kind: ImageUpdateAutomation
          metadata:
            name: podinfo
            namespace: flux-system
          spec:
            interval: 1m
            sourceRef:
              kind: GitRepository
              name: flux-system
            git:
              checkout:
                ref:
                  branch: main
              commit:
                author:
                  name: fluxcdbot
                  email: fluxcdbot@users.noreply.github.com
                messageTemplate: |
                  chore(podinfo): automated image update
          
                  Files changed:
                  {{ range $filename, $_ := .Changed.FileChanges -}}
                  - {{ $filename }}
                  {{ end -}}
              push:
                branch: main
            update:
              path: ./apps/base/podinfo
              strategy: Setters
          EOF
          
             79  cat > apps/overlays/dev/image-automation/kustomization.yaml <<'EOF'
          ---
          apiVersion: kustomize.config.k8s.io/v1beta1
          kind: Kustomization
          resources:
            - image-repository.yaml
            - image-policy.yaml
            - image-update.yaml
          EOF
          
             80  ls apps/overlays/dev/image-automation/
             81  cd clusters/lab/
             82  ls
             83  cd -
             84  cat > clusters/lab/image-automation.yaml <<'EOF'
          ---
          apiVersion: kustomize.toolkit.fluxcd.io/v1
          kind: Kustomization
          metadata:
            name: image-automation
            namespace: flux-system
          spec:
            interval: 5m
            retryInterval: 1m
            timeout: 3m
            sourceRef:
              kind: GitRepository
              name: flux-system
            path: ./apps/overlays/dev/image-automation
            prune: true
            wait: true
          EOF
          
             85  cd apps/base/podinfo
             86  cat deployment.yaml | grep -i image
             87  cd -
             88  cat > apps/base/podinfo/deployment.yaml <<'DEPEOF'
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
                    image: ghcr.io/stefanprodan/podinfo:6.7.1   # {"$imagepolicy": "flux-system:podinfo"}
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
          DEPEOF
          
             89  tail -3 apps/base/podinfo/deployment.yaml
             90  tail -10 apps/base/podinfo/deployment.yaml
             91  cat apps/base/podinfo/deployment.yaml | grep -i image
             92  git add .
             93  git commit -m "image automation"
             94  git push
             95  git pull
             96  git push
             97  history | grep -i flux
             98   flux reconcile source git flux-system
             99   flux reconcile kustomization flux-system
            100   flux reconcile kustomization apps-dev
            101   flux reconcile kustomization apps-staging
            102   flux reconcile kustomization image-automation
            103  flux get all
            104  flux get all
            105  flux get image all -A
            106  kubectl get pods -n dev
            107  kubectl get deployment -n dev
            108  kubectl get deployment podinfo -n dev
            109  kubectl get deployment podinfo -n dev -o jsonpath='{.spec.template.spec.containers[0].image}'
            110  kubectl get deployment -n staging
            111  kubectl get pods -n staging
            112  kubectl get deployment podinfo -n staging -o jsonpath='{.spec.template.spec.containers[0].image}'
            113  cat apps/base/podinfo/deployment.yaml | grep -i image
            114  cd apps/overlays/staging/
            115  ls
            116  cat kustomization.yaml
            117  flux get all
            118  flux suspend image update podinfo
            119  flux get all
            120  flux suspend image policy podinfo
            121  flux get all
            122  flux resume image update podinfo
            123  flux get all
            124  flux suspend image policy podinfo

   # Blue green deployment
               118  flux suspend image update podinfo
                 119  flux get all
                 120  flux suspend image policy podinfo
                 121  flux get all
                 122  flux resume image update podinfo
                 123  flux get all
                 124  flux suspend image policy podinfo
                 125  history
                 126  kubectl get pods
                 127  kubectl get pods -n dev
                 128  kubectl get pods -n staging
                 129  cd -
                 130  git pull
                 131  kubectl get service podinfo -n dev -o jsonpath='{.spec.selector}' | python -m json.tool 2>/dev/null || kubectl get service podinfo -n dev -o yaml | grep -A2 selector
                 132  cd apps/base/podinfo
                 133  ls
                 134  cat deployment.yaml
                 135  cd -
                 136  cat > apps/base/podinfo/deployment.yaml <<'EOF'
               ---
               apiVersion: apps/v1
               kind: Deployment
               metadata:
                 name: podinfo-blue
                 labels:
                   app: podinfo
                   color: blue
               spec:
                 replicas: 1
                 selector:
                   matchLabels:
                     app: podinfo
                     color: blue
                 template:
                   metadata:
                     labels:
                       app: podinfo
                       color: blue
                   spec:
                     containers:
                       - name: podinfo
                         image: ghcr.io/stefanprodan/podinfo:6.7.0
                         ports:
                           - name: http
                             containerPort: 9898
                         env:
                           - name: PODINFO_UI_COLOR
                             value: "#0066ff"
                           - name: PODINFO_UI_MESSAGE
                             value: "BLUE deployment - v6.7.0 - the current production"
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
               EOF
               
                 137  cat deployment.yaml
                 138  cd apps/base/podinfo
                 139  cat deployment.yaml
                 140  cd -
                 141  cat > apps/base/podinfo/deployment-green.yaml <<'EOF'
               ---
               apiVersion: apps/v1
               kind: Deployment
               metadata:
                 name: podinfo-green
                 labels:
                   app: podinfo
                   color: green
               spec:
                 replicas: 1
                 selector:
                   matchLabels:
                     app: podinfo
                     color: green
                 template:
                   metadata:
                     labels:
                       app: podinfo
                       color: green
                   spec:
                     containers:
                       - name: podinfo
                         image: ghcr.io/stefanprodan/podinfo:6.7.1
                         ports:
                           - name: http
                             containerPort: 9898
                         env:
                           - name: PODINFO_UI_COLOR
                             value: "#00cc66"
                           - name: PODINFO_UI_MESSAGE
                             value: "GREEN deployment - v6.7.1 - the new candidate"
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
               EOF
               
                 142  cat apps/base/podinfo/deployment-green.yaml | head -10
                 143  cat apps/base/podinfo/deployment.yaml | head -10
                 144  cat > apps/base/podinfo/service.yaml <<'EOF'
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
                   color: blue
                 ports:
                   - name: http
                     port: 9898
                     targetPort: http
               EOF
               
                 145  cat apps/base/podinfo/service.yaml
                 146  vi apps/base/podinfo/kustomization.yaml
                 147  cat apps/base/podinfo/kustomization.yaml
                 148  rm apps/overlays/dev/image-automation/*
                 149  kubectl get pods -n dev
                 150  kubectl deploy deployment podinfo -n dev
                 151  kubectl delete deployment podinfo -n dev
                 152  flux reconcile source git flux-system
                 153  flux reconcile kustomization apps-dev
                 154  kubectl get pods -n dev
                 155  git add apps/base/podinfo/
                 156  git commit -n " blue green"
                 157  git commit -m " blue green"
                 158  git push
                 159  flux reconcile source git flux-system
                 160  flux reconcile kustomization apps-dev
                 161  flux get all
                 162  kubectl get pods -n dev
                 163  kubectl get endpoints -n dev
                 164  kubectl get endpoints podinfo -n dev
                 165  kubectl get svc -n dev
                 166  kubectl port-forward svc/podinfo 9898:9898 -n dev
                 167  vi apps/base/podinfo/service.yaml
                 168  git add apps/base/podinfo/service.yaml
                 169  git commit -m "service update"
                 170  git push
                 171  flux reconcile source git flux-system
                 172  flux reconcile kustomization apps-dev
                 173  kubectl port-forward svc/podinfo 9898:9898 -n dev
                 174  vi apps/base/podinfo/service.yaml
                 175  git add apps/base/podinfo/service.yaml
                 176  git commit -m "service update"
                 177  git push
                 178  flux reconcile source git flux-system
                 179  flux reconcile kustomization apps-dev
                 180  kubectl port-forward svc/podinfo 9898:9898 -n dev

        # validation of BG
                  curl -s http://localhost:9898/api/info
                  13  for i in 1 2 3 4 5; do   echo -n "Request $i: ";   curl -s http://localhost:9898/api/info | jq -r '"\(.hostname)  -  \(.message)"'; done
                  14



   # Canary + Flagger

              3  kubectl get deployments -n dev
              4  rm -f apps/base/podinfo/deployment-green.yaml
              5
              6  cd ericson-infra-d2/
              7  cd apps/base/podinfo
              8  ls
              9  rm deployment-green.yaml
             10  cd -
             11  cat > apps/base/podinfo/deployment.yaml <<'EOF'
          ---
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: podinfo
            labels:
              app: podinfo
          spec:
            replicas: 2
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
                    image: ghcr.io/stefanprodan/podinfo:6.7.0
                    ports:
                      - name: http
                        containerPort: 9898
                    env:
                      - name: PODINFO_UI_COLOR
                        value: "#0066ff"
                    livenessProbe:
                      httpGet:
                        path: /healthz
                        port: 9898
                    readinessProbe:
                      httpGet:
                        path: /readyz
                        port: 9898
                    resources:
                      requests:
                        cpu: 100m
                        memory: 64Mi
          EOF
          
             12  cat > apps/base/podinfo/service.yaml <<'EOF'
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
          
             13  cd -
             14  ls
             15  vi kustomization.yaml
             16  kubectl delete deployment podinfo-blue -n dev --ignore-not-found
             17  kubectl delete deployment podinfo-green -n dev --ignore-not-found
             18
             19  git add .
             20  git commit -m " delete the deployment"
             21  git push
             22  flux reconcile source git flux-system
             23  cd -
             24  flux reconcile source git flux-system
             25  flux reconcile kustomization apps-dev
             26  kubectl get all -n dev
             27  mkdir apps/base/flagger
             28  cd infrastructure/sources/
             29  ls
             30  cat podinfo-helm.yaml
             31  cd -
             32  cat > infrastructure/sources/flagger.yaml <<'EOF'
          ---
          apiVersion: source.toolkit.fluxcd.io/v1
          kind: HelmRepository
          metadata:
            name: flagger
            namespace: flux-system
          spec:
            interval: 1h
            url: https://flagger.app
          EOF
          
             33  cd -
             34  cat flagger.yaml
             35  cat podinfo-helm.yaml
             36  cd -
             37  cd apps/base/flagger/
             38  ls
             39  cd -
             40  cat > apps/base/flagger/helmrelease.yaml <<'EOF'
          ---
          apiVersion: helm.toolkit.fluxcd.io/v2
          kind: HelmRelease
          metadata:
            name: flagger
            namespace: flux-system
          spec:
            interval: 5m
            releaseName: flagger
            targetNamespace: flagger-system
            install:
              createNamespace: true
              remediation:
                retries: 3
            upgrade:
              remediation:
                retries: 3
                strategy: rollback
            chart:
              spec:
                chart: flagger
                version: "1.x"
                sourceRef:
                  kind: HelmRepository
                  name: flagger
                  namespace: flux-system
            values:
              meshProvider: kubernetes      # use kubernetes provider (no service mesh needed)
              metricsServer: http://prometheus-server.monitoring.svc.cluster.local:80
              prometheus:
                install: true               # install bundled Prometheus
          EOF
          
             41  cat > apps/base/flagger/kustomization.yaml <<'EOF'
          ---
          apiVersion: kustomize.config.k8s.io/v1beta1
          kind: Kustomization
          resources:
            - helmrelease.yaml
          EOF
          
             42  cd infrastructure/sources/
             43  ls
             44  cat kustomization.yaml
             45  vi kustomization.yaml
             46  cd -
             47  cd apps/overlays/dev/
             48  ls
             49  cat kustomization.yaml
             50  vi kustomization.yaml
             51  cat kustomization.yaml
             52  history
             53  git add .
             54  cd -
             55  git add .
             56  git commit -m "canary+flagger"
             57  git push
             58  flux reconcile source git flux-system
             59  flux reconcile kustomization flux-system
             60  flux reconcile kustomization infrastructure
             61  flux reconcile kustomization apps-dev
             62  kubectl get ns
             63  kubectl get deployments -n flagger-system
             64  kubectl get all -n flagger-system
             65  flux get hr -A


              3  kubectl get deployments -n dev
              4  rm -f apps/base/podinfo/deployment-green.yaml
              5
              6  cd ericson-infra-d2/
              7  cd apps/base/podinfo
              8  ls
              9  rm deployment-green.yaml
             10  cd -
             11  cat > apps/base/podinfo/deployment.yaml <<'EOF'
          ---
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: podinfo
            labels:
              app: podinfo
          spec:
            replicas: 2
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
                    image: ghcr.io/stefanprodan/podinfo:6.7.0
                    ports:
                      - name: http
                        containerPort: 9898
                    env:
                      - name: PODINFO_UI_COLOR
                        value: "#0066ff"
                    livenessProbe:
                      httpGet:
                        path: /healthz
                        port: 9898
                    readinessProbe:
                      httpGet:
                        path: /readyz
                        port: 9898
                    resources:
                      requests:
                        cpu: 100m
                        memory: 64Mi
          EOF
          
             12  cat > apps/base/podinfo/service.yaml <<'EOF'
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
          
             13  cd -
             14  ls
             15  vi kustomization.yaml
             16  kubectl delete deployment podinfo-blue -n dev --ignore-not-found
             17  kubectl delete deployment podinfo-green -n dev --ignore-not-found
             18
             19  git add .
             20  git commit -m " delete the deployment"
             21  git push
             22  flux reconcile source git flux-system
             23  cd -
             24  flux reconcile source git flux-system
             25  flux reconcile kustomization apps-dev
             26  kubectl get all -n dev
             27  mkdir apps/base/flagger
             28  cd infrastructure/sources/
             29  ls
             30  cat podinfo-helm.yaml
             31  cd -
             32  cat > infrastructure/sources/flagger.yaml <<'EOF'
          ---
          apiVersion: source.toolkit.fluxcd.io/v1
          kind: HelmRepository
          metadata:
            name: flagger
            namespace: flux-system
          spec:
            interval: 1h
            url: https://flagger.app
          EOF
          
             33  cd -
             34  cat flagger.yaml
             35  cat podinfo-helm.yaml
             36  cd -
             37  cd apps/base/flagger/
             38  ls
             39  cd -
             40  cat > apps/base/flagger/helmrelease.yaml <<'EOF'
          ---
          apiVersion: helm.toolkit.fluxcd.io/v2
          kind: HelmRelease
          metadata:
            name: flagger
            namespace: flux-system
          spec:
            interval: 5m
            releaseName: flagger
            targetNamespace: flagger-system
            install:
              createNamespace: true
              remediation:
                retries: 3
            upgrade:
              remediation:
                retries: 3
                strategy: rollback
            chart:
              spec:
                chart: flagger
                version: "1.x"
                sourceRef:
                  kind: HelmRepository
                  name: flagger
                  namespace: flux-system
            values:
              meshProvider: kubernetes      # use kubernetes provider (no service mesh needed)
              metricsServer: http://prometheus-server.monitoring.svc.cluster.local:80
              prometheus:
                install: true               # install bundled Prometheus
          EOF
          
             41  cat > apps/base/flagger/kustomization.yaml <<'EOF'
          ---
          apiVersion: kustomize.config.k8s.io/v1beta1
          kind: Kustomization
          resources:
            - helmrelease.yaml
          EOF
          
             42  cd infrastructure/sources/
             43  ls
             44  cat kustomization.yaml
             45  vi kustomization.yaml
             46  cd -
             47  cd apps/overlays/dev/
             48  ls
             49  cat kustomization.yaml
             50  vi kustomization.yaml
             51  cat kustomization.yaml
             52  history
             53  git add .
             54  cd -
             55  git add .
             56  git commit -m "canary+flagger"
             57  git push
             58  flux reconcile source git flux-system
             59  flux reconcile kustomization flux-system
             60  flux reconcile kustomization infrastructure
             61  flux reconcile kustomization apps-dev
             62  kubectl get ns
             63  kubectl get deployments -n flagger-system
             64  kubectl get all -n flagger-system
             65  flux get hr -A
             66  history
             67  cat > apps/base/podinfo/canary.yaml <<'EOF'
          ---
          apiVersion: flagger.app/v1beta1
          kind: Canary
          metadata:
            name: podinfo
            namespace: dev
          spec:
            provider: kubernetes
            targetRef:
              apiVersion: apps/v1
              kind: Deployment
              name: podinfo
            service:
              port: 9898
              targetPort: 9898
            analysis:
              interval: 30s
              threshold: 5
              maxWeight: 50
              stepWeight: 10
              metrics:
                - name: request-success-rate
          
          
          
             68  cat > apps/base/podinfo/canary.yaml <<'EOF'
          ---
          apiVersion: flagger.app/v1beta1
          kind: Canary
          metadata:
            name: podinfo
            namespace: dev
          spec:
            provider: kubernetes
            targetRef:
              apiVersion: apps/v1
              kind: Deployment
              name: podinfo
            service:
              port: 9898
              targetPort: 9898
            analysis:
              interval: 30s
              threshold: 5
              maxWeight: 50
              stepWeight: 10
              metrics:
                - name: request-success-rate
                  thresholdRange:
                    min: 99
                  interval: 30s
                - name: request-duration
                  thresholdRange:
                    max: 500
                  interval: 30s
              webhooks:
                - name: load-test
                  type: rollout
                  url: http://flagger-loadtester.flagger-system/
                  timeout: 5s
                  metadata:
                    cmd: "hey -z 1m -q 10 -c 2 http://podinfo-canary.dev:9898/"
          EOF
          
             69  cat apps/base/podinfo/canary.yaml
             70  cd apps/base/podinfo
             71  ls
             72  vi kustomization.yaml
             73  cd ../../..
             74  git add .
             75  git commit -m
             76  git commit -m "canary config file"
             77  git push
             78  flux reconcile source git flux-system
             79  flux reconcile kustomization apps-dev
             80  kubectl get canary -n dev
             81  kubectl get canary -n dev
             82  kubectl get canary -n dev
             83  kubectl get canary -n dev
             84  sleep 15
             85  sleep 15
             86  kubectl get canary -n dev
             87  kubectl describe canary -n dev
             88  cat > apps/base/flagger/loadtester.yaml <<'EOF'
          ---
          apiVersion: helm.toolkit.fluxcd.io/v2
          kind: HelmRelease
          metadata:
            name: flagger-loadtester
            namespace: flux-system
          spec:
            interval: 5m
            releaseName: flagger-loadtester
            targetNamespace: flagger-system
            install:
              createNamespace: false
              remediation:
                retries: 3
            chart:
              spec:
                chart: loadtester
                version: "0.x"
                sourceRef:
                  kind: HelmRepository
                  name: flagger
                  namespace: flux-system
          EOF
          
             89  vi apps/base/flagger/kustomization.yaml
             90  git add .
             91  git commit -m "loadtester config"
             92  git push
             93  flux reconcile source git flux-system
             94  flux reconcile kustomization apps-dev
             95  kubectl get pods -n flagger-system
             96  flux get hr
             97  flux get hr -A
             98  cat apps/base/podinfo/deployment.yaml | grep -i image
             99  kubectl get pods -n dev
            100  kubectl get deployment podinfo
            101  kubectl get deployment podinfo -o yaml
            102  kubectl get deployment podinfo -n dev -o yaml
            103  kubectl get deployment podinfo -n dev -o yaml | grep -i image
            104  sed -i 's|podinfo:6.7.0|podinfo:6.7.1|' apps/base/podinfo/deployment.yaml
            105  grep "image:" apps/base/podinfo/deployment.yaml
            106
            107  git add .
            108  git commmit -m "image refresh to 6.7.1"
            109  git commit -m "image refresh to 6.7.1"
            110  git push
            111  flux reconcile source git flux-system
            112  flux reconcile kustomization apps-dev
            113  kubectl get pods -n dev
            114  kubectl events -n dev --watch
            115  kubectl events -n dev --watch
            116  kubectl get deployment podinfo -n dev -o yaml | grep -i image
            117  kubectl get pods -n dev
            118  kubectl get canary podinfo -n dev
            119  kubectl describe canary podinfo -n dev






