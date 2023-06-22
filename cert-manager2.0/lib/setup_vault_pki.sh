#!/bin/sh

# enables the public pki engine secret for both intermediate and issuer certificates
enable_public_pki_engine() {

  # enable pki - intermediate
  vault secrets enable -path=pub_pki_int pki
  vault secrets tune -max-lease-ttl=43800h pub_pki_int

  vault write pub_pki_int/config/urls \
                    issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                    crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"

  # enable pki - issuer
  vault secrets enable -path=pub_pki_iss pki
  vault secrets tune -max-lease-ttl=8760h pub_pki_iss

  vault write pub_pki_iss/config/urls \
                    issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                    crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"
}

# enables the private pki engine secret for root, intermediate and issuer certificates
enable_private_pki_engine() {

  # enable pki - root
  vault secrets enable -path=pri_pki pki
  vault secrets tune -max-lease-ttl=87600h pri_pki

  vault write pri_pki/config/urls \
                    issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                    crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"

  # enable pki - intermediate
  vault secrets enable -path=pri_pki_int pki
  vault secrets tune -max-lease-ttl=43800h pri_pki_int

  vault write pri_pki_int/config/urls \
                    issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                    crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"

  # enable pki - issuer
  vault secrets enable -path=pri_pki_iss pki
  vault secrets tune -max-lease-ttl=8760h pri_pki_iss

  vault write pri_pki_iss/config/urls \
                    issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                    crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"
}

# creates a public pki role for the public certificate issuer
create_public_pki_role() {
  vault write pub_pki_iss/roles/vault \
        allowed_domains="${DOMAIN}" \
        allow_subdomains=true \
        allow_wildcard_certificates=false \
        max_ttl=2160h
}

# creates a private pki role for the public certificate issuer
create_private_pki_role() {
  vault write pri_pki_iss/roles/vault \
        allowed_domains="${DOMAIN}" \
        allow_subdomains=true \
        allow_wildcard_certificates=false \
        max_ttl=2160h
}

# sets up the k8 resource that links cert-manager and the public vault pki engine
create_public_k8_issuer() {
  kubectl apply --filename - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${PUBLIC_ISSUER}
  namespace: ${NAMESPACE}
spec:
  vault:
    server: http://${LOCAL_HOSTNAME}
    path: pub_pki_iss/sign/vault
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: issuer
        secretRef:
          name: ${ISSUER_SECRET_REF}
          key: token
EOF
}

# sets up the k8 resource that links cert-manager and the private vault pki engine
create_private_k8_issuer() {
  kubectl apply --filename - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${PRIVATE_ISSUER}
  namespace: ${NAMESPACE}
spec:
  vault:
    server: http://${LOCAL_HOSTNAME}
    path: pri_pki_iss/sign/vault
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: issuer
        secretRef:
          name: ${ISSUER_SECRET_REF}
          key: token
EOF
}

# configure vault to integrate with kubernetes
configure_k8_auth() {

  # create a single vault policy for both private and public
    vault policy write pki - <<EOF
path "pki*"                                 { capabilities = ["read", "list"] }
path "pub_pki_iss/sign/vault"               { capabilities = ["create", "update"] }
path "pub_pki_iss/issue/vault"              { capabilities = ["create"] } 
path "pri_pki_iss/sign/vault"               { capabilities = ["create", "update"] }
path "pri_pki_iss/issue/vault"              { capabilities = ["create"] } 
EOF

  # create kubernetes service account
  kubectl create sa ${ISSUER_SA_REF} --namespace ${NAMESPACE}

  # create kubernetes service account token for vault to login as a sytemuser
  kubectl apply --filename - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${ISSUER_SECRET_REF}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${ISSUER_SA_REF}
type: kubernetes.io/service-account-token
EOF

  # enable kubernetes mode on vault
  vault auth enable kubernetes

  kubectl exec vault-0 --namespace ${NAMESPACE} -- sh -c 'vault write auth/kubernetes/config \
                  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
                  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
                  kubernetes_host="https://${KUBERNETES_PORT_443_TCP_ADDR}:443"'

  vault write auth/kubernetes/role/issuer \
                    bound_service_account_names=${ISSUER_SA_REF} \
                    bound_service_account_namespaces=${NAMESPACE} \
                    policies=pki \
                    ttl=20m
}

NAMESPACE="${NAMESPACE:=cert-manager}"
ISSUER_SECRET_REF="${ISSUER_SECRET_REF:=issuer-token}"
ISSUER_SA_REF="${ISSUER_SA_REF:=issuer}"
HOSTNAME="${HOSTNAME:=vault.127.0.0.1.nip.io}"
LOCAL_HOSTNAME="${LOCAL_HOSTNAME:=vault:8200}"
PUBLIC_ISSUER="${PUBLIC_ISSUER:=vault-public-issuer}"
PRIVATE_ISSUER="${PRIVATE_ISSUER:=vault-private-issuer}"