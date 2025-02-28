# Kargo Deployment Example

Just an example, if you're not well versed in Argo CD and/or Kustomize, you WILL get lost.

## Deploy

```shell
until kustomize build --enable-helm https://github.com/christianh814/kargo-deployment-example/bootstrap | kubectl apply -f  - ; do sleep 3; done
```

## External Secret 

The following won't work for you unless you export the right stuff. This HAS to be done RIGHT AFTER YOU DEPLOY ^

```shell
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: kargo-demo-css
spec:
  provider:
    fake:
      data:
      - key: "/data/kargo_admin_password_hash"
        value: "${KARGO_ADMIN_HASH}"
        version: "v1"
      - key: "/data/kargo_admin_token_signing_key"
        value: "iwishtowashmyirishwristwatch"
        version: "v1"
      - key: "/data/password"
        value: "${KARGO_GH_PAT}"
        version: "v1"
      - key: "/data/username"
        value: "${KARGO_GH_USERNAME}"
        version: "v1"
      - key: "/data/repoURL"
        value: "https://github.com/christianh814/kargo-deployment-example"
        version: "v1"
      - key: "/data/admin_password"
        value: "${ARGOCD_ADMIN_PASSWORD}"
        version: "v1"
      - key: "/data/admin_password_mtime"
        value: "$(date +%FT%T%Z)"
        version: "v1"
EOF
```

## Wait for Application to be ready

You probably need to wait for the application controller before anything else.

```shell
kubectl rollout status sts/argocd-application-controller -n argocd
```

Application takes a while to be ready, but it'll eventually come back.

```shell
kubectl wait --timeout=300s --for=jsonpath='{.status.sync.status}'=Synced app/bootstrap -n argocd
```

## Repository Layout

This is an example of a Mono-Repo (where everything is contained herein). The idea being to "GitOps Everything" (or as much as you can), for Kargo + Argo CD.

```text annotate
.
├── app # Manifests that Kargo will promote
│   ├── base
│   └── stages
│       ├── prod
│       ├── test
│       └── uat
├── bootstrap # Entrypoint for this repo. Applying this directory will "deploy everything" in this repo
├── configs # Configurations specific to each installation. (e.g. Applications, ApplicationSets, Kargo Projects, Kargo Pipelines, etc)
│   ├── argocd
│   └── kargo
└── system # Installation manifests (i.e. the helmcharts to install the specified tool)
    ├── argocd
    ├── argo-rollouts
    ├── cert-manager
    ├── external-secrets
    ├── kargo
    └── nginx
```
