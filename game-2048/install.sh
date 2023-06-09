#!/bin/sh

kubectl apply -f deploy.yaml


# kubectl apply --filename -<<EOF
# apiVersion: cert-manager.io/v1
# kind: Certificate
# metadata:
#   name: game-cert
#   namespace: dummy-2048
# spec:
#   secretName: game.127.0.0.1.nip.io
#   issuerRef:
#     name: vault-issuer
#     kind: ClusterIssuer
#   commonName: vault-issuer
#   dnsNames:
#   - game.127.0.0.1.nip.io
# EOF