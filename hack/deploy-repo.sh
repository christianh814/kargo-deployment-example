#!/bin/bash
repoURL="https://github.com/christianh814/kargo-deployment-example/bootstrap"

##
# Make sure the right environment variables are set
[[ ${#KARGO_ADMIN_HASH} -eq 0 ]] && echo "KARGO_ADMIN_HASH is not set" && exit 1
[[ ${#KARGO_GH_PAT} -eq 0 ]] && echo "KARGO_GH_PAT is not set" && exit 1
[[ ${#KARGO_GH_USERNAME} -eq 0 ]] && echo "KARGO_GH_USERNAME is not set" && exit 1
[[ ${#ARGOCD_ADMIN_PASSWORD} -eq 0 ]] && echo "ARGOCD_ADMIN_PASSWORD not set" && exit 1

##
# Kustomize build the URL
echo -n "Applying kustomize build manifests..."
counter=0
until kustomize build --enable-helm ${repoURL} | kubectl apply -f  -  > /dev/null 2>&1
do
	counter=$((counter+1))
	[[ $counter -eq 20 ]] && echo "Threshold met, unrecoverable \"kustomize build\" error" && exit 1
	sleep 3
done
echo "DONE"

##
# Apply ClusterSecretStore
echo "Applying ClusterSecretStore"
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

##
# Replace the App of Apps to speed things up
echo "Nudging the App of Apps"
kubectl replace -f bootstrap/app-of-apps.yaml

##
# Wait for the ArgoCD to be ready
echo "Waiting for Argo CD to be ready"
kubectl rollout status sts/argocd-application-controller -n argocd

##
# Wait for the Bootstrap to be ready
echo "Waiting for Bootstrap Application to be ready"
kubectl wait --timeout=300s --for=jsonpath='{.status.sync.status}'=Synced app/bootstrap -n argocd

##
##
