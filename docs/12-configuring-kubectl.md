# Configuring kubectl for Remote Access

In this lab you will generate a kubeconfig file for the `kubectl` command line utility based on the `admin` user credentials.

> Run the commands in this lab from the same directory used to generate the admin client certificates.

## The Admin Kubernetes Configuration File

Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

[//]: # (host:controlplane01)

On `controlplane01`

Get the kube-api server load-balancer IP.

```bash
LOADBALANCER=$(dig +short loadbalancer)
```

Generate a kubeconfig file suitable for authenticating as the `admin` user:

```bash
{

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${LOADBALANCER}:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.crt \
    --client-key=admin.key

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}
```

Reference doc for kubectl config [here](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)

## Verification

Check the health of the remote Kubernetes cluster:

```
kubectl get componentstatuses
```

Output will be similar to this. It may or may not list both etcd instances, however this is OK if you verified correct installation of etcd in lab 7.

```
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   ok
```

List the nodes in the remote Kubernetes cluster:

```bash
kubectl get nodes
```

> output

```
NAME       STATUS      ROLES    AGE    VERSION
node01     NotReady    <none>   118s   v1.37.1
node02     NotReady    <none>   118s   v1.37.1
```

## Optional - Access the cluster from your workstation

The `~/.kube/config` created above refers to the certificate files on `controlplane01`. To use `kubectl` on your own computer, build a self-contained copy with the certificates embedded.

On `controlplane01`:

```bash
{
  LOADBALANCER=$(dig +short loadbalancer)

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://${LOADBALANCER}:6443 \
    --kubeconfig=workstation.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.crt \
    --client-key=admin.key \
    --embed-certs=true \
    --kubeconfig=workstation.kubeconfig

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=workstation.kubeconfig

  kubectl config use-context kubernetes-the-hard-way --kubeconfig=workstation.kubeconfig
}
```

Then on your workstation (not in a VM), copy it to a separate file so it does not overwrite any existing `~/.kube/config`:

* Apple Silicon

    ```bash
    mkdir -p ~/.kube
    multipass exec controlplane01 -- cat workstation.kubeconfig > ~/.kube/kthw-config
    ```

* VirtualBox (from the `vagrant` directory)

    ```bash
    mkdir -p ~/.kube
    vagrant ssh controlplane01 -c 'cat workstation.kubeconfig' > ~/.kube/kthw-config
    ```

Use it with:

```bash
export KUBECONFIG=~/.kube/kthw-config
kubectl get nodes
```

Notes:

* `kubectl` on your workstation needs to be within one minor version of the cluster.
* Requests go through the load balancer, so they keep working if one controlplane node is down.
* Pod and Service IPs are not routable from your workstation. Use `kubectl port-forward` to reach an application, for example `kubectl port-forward svc/nginx 8080:80` and then open `http://localhost:8080`.
* This file grants full admin access to the cluster. Keep it private.

Next: [Deploy Pod Networking](./13-configure-pod-networking.md)</br>
Prev: [TLS Bootstrapping Kubernetes Workers](./11-tls-bootstrapping-kubernetes-workers.md)
