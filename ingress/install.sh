#!/bin/bash
helm upgrade --install app-ingress ingress-nginx/ingress-nginx --namespace ingress --create-namespace -f values.yaml