# Kubernetes Ingress

This project contains a script to set up an ingress controller on Kubernetes.

## Requirements

- Kuberenetes cluster
- Helm
- Kubectl

## How to use

Double click the ```install.sh``` file or run the command ```install.sh``` in the terminal from the cloned directory.

## How to confirm deployment

Run the following command to view if the pods are ready:

```kubectl get all -n ingress```

If all goes well and the service's external IP is exposed correctly then you should see an NGINX 404 page when you click on the following URL: http://localhost

## Problems

If you do not get a NGINX 404 page, this means that either another application is utilising the localhost URL or the service external IP is stuck in a pending state.

Run the following command to view the state of your service's EXTERNAL-IP address:

```kubectl get svc -n ingress```

If you see a similar \<pending\> value below the EXTERNAL-IP column as the result below:

```
NAME                                                     TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/app-ingress-ingress-nginx-controller             LoadBalancer   10.103.79.131    <pending>     80:30204/TCP,443:31341/TCP   166m
```

## Solutions

- Restart the cluster
- Stop the other application using that particular external IP
- Restart the Host/PC

Run this command again:

```kubectl get svc -n ingress```

The result should look like the following:

```
NAME                                                     TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/app-ingress-ingress-nginx-controller             LoadBalancer   10.103.79.131    localhost     80:30204/TCP,443:31341/TCP   166m
```