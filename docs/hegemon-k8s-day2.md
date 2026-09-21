# hegemon: Kubernetes day-2 add-ons — storage and ingress

A fresh k0s install ships with neither a `StorageClass` nor an `IngressClass`.
This runbook is what closes that gap on `hegemon`, and how to reach anything
deployed afterward.

## What's installed

1. **`rancher/local-path-provisioner`**, set as the default `StorageClass`.
   `hegemon` is a single-node cluster today (control plane and worker on one
   box, per [its README](../nodes/hegemon/README.md)), so `local-path`'s usual
   caveat — a volume is pinned to whichever node provisioned it — costs
   nothing yet: there is only one node. Revisit once `helios` joins as a
   second node.
2. **`ingress-nginx`**, patched to `hostNetwork: true` so the controller binds
   directly on `hegemon`'s LAN IP (`192.168.68.52`), ports 80/443. No
   `NodePort`, no external load balancer — this cluster is reached from
   inside the LAN only, nothing is exposed outside it.

## Reproducing it

```sh
k0s kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
k0s kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

k0s kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.0/deploy/static/provider/baremetal/deploy.yaml
k0s kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  -p '{"spec":{"template":{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}}}'
```

## Reaching a deployed service

DNS follows this lab's existing `home.arpa` naming (see `fleet.home.arpa`,
used elsewhere in this repo) — regular DNS, not mDNS, served by AdGuard Home
on the Home Assistant Pi. AdGuard carries one wildcard rewrite for this:

```
*.apps.home.arpa  ->  192.168.68.52
```

So any `Ingress` with a host under `*.apps.home.arpa` resolves automatically —
no further AdGuard changes needed per service. Give an `Ingress` a host like
`forgejo.apps.home.arpa`, point it at `ingressClassName: nginx`, and it's
reachable from any device on the LAN.

## Verifying the path end to end

A `PersistentVolumeClaim` binding and an `Ingress` returning traffic both need
checking — a healthy provisioner or controller pod doesn't guarantee either
actually works:

```sh
k0s kubectl get storageclass         # local-path should show (default)
k0s kubectl get ingressclass         # nginx should be listed
k0s kubectl get pods -n ingress-nginx -o wide   # controller's IP should be hegemon's LAN IP, not a pod IP
```

Then deploy anything with a PVC and an `Ingress` and confirm the PVC goes
`Bound` and `curl -H 'Host: <name>.apps.home.arpa' http://192.168.68.52/`
returns a real response, not a connection error or nginx's default backend.

## What this doesn't cover

- **Secrets.** No secrets manager is installed. Anything needing one is still
  an open question.
- **TLS.** Not set up — internal-only traffic over plain HTTP is accepted for
  now.
- **Multi-node storage.** `local-path` stops being the right default the
  moment a second node joins; see the caveat above.
