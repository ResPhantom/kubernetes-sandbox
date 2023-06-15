#!/bin/sh

enable_pki_engine() {

  # enable pki - root
  vault secrets enable pki
  vault secrets tune -max-lease-ttl=87600h pki

  vault write pki/config/urls \
                    issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                    crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"

  # enable pki - intermediate
  vault secrets enable -path=pki_int pki
  vault secrets tune -max-lease-ttl=43800h pki_int

  vault write pki_int/config/urls \
                    issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                    crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"

  # enable pki - issuer
  vault secrets enable -path=pki_iss pki
  vault secrets tune -max-lease-ttl=8760h pki_iss

  vault write pki_iss/config/urls \
                    issuing_certificates="http://${HOSTNAME}/v1/pki/ca" \
                    crl_distribution_points="http://${HOSTNAME}/v1/pki/crl"
}

create_pki_role() {
  vault write pki_iss/roles/vault \
        organization="${ORGANIZATION}" \
        allowed_domains="${DOMAIN}" \
        allow_subdomains=true \
        allow_wildcard_certificates=false \
        max_ttl=2160h

  vault policy write pki - <<EOF
path "pki*"                             { capabilities = ["read", "list"] }
path "pki_iss/sign/vault"               { capabilities = ["create", "update"] }
path "pki_iss/issue/vault"              { capabilities = ["create"] } 
EOF
}

configure_k8_auth() {
kubectl create sa ${ISSUER_SA_REF} --namespace ${NAMESPACE}

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

ISSUER_SECRET_REF="${ISSUER_SECRET_REF:=issuer-token}"
ISSUER_SA_REF="${ISSUER_SA_REF:=issuer}"
HOSTNAME="${HOSTNAME:=vault.${DOMAIN}}"
ORGANIZATION="${ORGANIZATION:=vault}"