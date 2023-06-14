#!/bin/sh
# git repo: https://github.com/bitnami/charts/tree/main/bitnami/keycloak
# helm artifact: https://artifacthub.io/packages/helm/bitnami/keycloak

. $(dirname $(readlink -f $0))/../install-lib.sh

HOSTNAME="keycloak.${DOMAIN}"

helm upgrade --install keycloak oci://registry-1.docker.io/bitnamicharts/keycloak \
             --namespace keycloak \
             --create-namespace \
             --set ingress.enabled=true \
             --set ingress.hostname=${HOSTNAME} \


# A manual step is required for Kubernetes integration
# You will have to update your cluster config on the master nodes

# kubectl get pod kube-apiserver-docker-desktop -n kube-system -o=jsonpath='{.spec.containers[0].command}'








# kubectl config set-credentials USER_NAME \
#    --auth-provider=oidc \
#    --auth-provider-arg=idp-issuer-url=( issuer url ) \
#    --auth-provider-arg=client-id=( your client id ) \
#    --auth-provider-arg=




# KEYCLOAK_USERNAME=admin-user
# KEYCLOAK_PASSWORD=admin-password
# KEYCLOAK_URL=https://keycloak.zufar.io:8443
# KEYCLOAK_REALM=IAM
# KEYCLOAK_CLIENT_ID=kubernetes
# KEYCLOAK_CLIENT_SECRET=eef3e405-76d3-4e7d-bc2b-8597cd447ca8




# --oidc-issuer-url=https://<KEYCLOAK_URL>:<KEYCLOAK_PORT>/auth/realms/<REALM> \
# --oidc-client-id=kubernetes \
# --oidc-groups-claim=user_groups \
# --oidc-username-claim=preferred_username \
# --oidc-groups-prefix="oidc:" \
# --oidc-username-prefix="oidc:" \
# --oidc-ca-file=/var/lib/kubernetes/keycloak.crt \




# spec:
#   kubeAPIServer:
#     oidcClientID: kubernetes
#     oidcGroupsClaim: groups
#     oidcGroupsPrefix: 'keycloak:'
#     oidcIssuerURL: https://<keycloakserverurl>/auth/realms/master
#     oidcUsernameClaim: email