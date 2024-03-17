# [`owntube/peertube-runner`](https://github.com/OwnTube-tv/peertube-runner)

Containerized [@peertube/peertube-runner](https://www.npmjs.com/package/@peertube/peertube-runner) for remote execution
of transcoding jobs in Kubernetes.

## Container Image Variants

### Image Variant 1: `owntube/peertube-runner:v521` PeerTube v5.2.1 Runner

Build the container image:

```bash
docker build -f Dockerfile.bullseye -t owntube/peertube-runner:v521 .
```

Test running the PeerTube runner server:

```bash
docker run -it --rm -u root --name v521-runner-server \
  -v $PWD/dot-local:/home/peertube/.local/share/peertube-runner-nodejs \
  -v $PWD/dot-config:/home/peertube/.config/peertube-runner-nodejs \
  -v $PWD/dot-cache:/home/peertube/.cache/peertube-runner-nodejs \
  owntube/peertube-runner:v521 peertube-runner server
```

### Image Variant 2: `owntube/peertube-runner:v603` (`:latest`) PeerTube v6.0.3 Runner

Build the container image:

```bash
docker build -f Dockerfile.bookworm -t owntube/peertube-runner:v603 .
```

Test running the PeerTube runner server:

```bash
docker run -it --rm -u root --name v603-runner-server \
  -v $PWD/dot-local:/home/peertube/.local/share/peertube-runner-nodejs \
  -v $PWD/dot-config:/home/peertube/.config/peertube-runner-nodejs \
  -v $PWD/dot-cache:/home/peertube/.cache/peertube-runner-nodejs \
  owntube/peertube-runner:v603 peertube-runner server
```

## Kubernetes Deployment

**Prerequisites:** Have a Kubernetes cluster with internet connectivity and persistent storage; the _StorageClass_
should support `.spec.accessModes[]` `ReadWriteMany` (e.g. [MicroK8s HostPath Storage](https://microk8s.io/docs/addon-hostpath-storage)),
as different container runtimes need to mount the PeerTube runner server socket as their mechanism of Inter-Process
Communication (IPC).

### Setup Step 1: Configure Persistent Storage

We need the following _PersistentVolumeClaims_ (PVCs):

1. `peertube-runner-local` for things persisted in `/home/peertube/.local/share/peertube-runner-nodejs`
2. `peertube-runner-config` for the tool's internal configs in `/home/peertube/.config/peertube-runner-nodejs`
3. `peertube-runner-cache` for file storage during task execution in `/home/peertube/.cache/peertube-runner-nodejs`

If we had a namespace named "peertube" and a storage class named "microk8s-hostpath", it could look like this:

```bash
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: peertube-runner-local
  namespace: peertube
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: microk8s-hostpath
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: peertube-runner-config
  namespace: peertube
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: microk8s-hostpath
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: peertube-runner-cache
  namespace: peertube
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: microk8s-hostpath
  resources:
    requests:
      storage: 10Gi
EOF
```

### Setup Step 2: Create a PeerTube Runner Pod

To create a _Pod_ with 2 containers in the namespace "peertube", each running a PeerTube Runner server with the
_PersistentVolumes_ (PVs) from _Setup Step 1_ above, and apply a Kubernetes manifest like this one:

```bash
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  name: peertube-runner-pod
  namespace: peertube
spec:
  securityContext:
    runAsUser: 999
    fsGroup: 999
  containers:
    - name: peertube-runner-1
      image: owntube/peertube-runner:v521
      command: ["peertube-runner"]
      args: ["server", "--id", "peertube-runner-1"]
      volumeMounts:
        - name: peertube-runner-local
          mountPath: /home/peertube/.local/share/peertube-runner-nodejs
        - name: peertube-runner-config
          mountPath: /home/peertube/.config/peertube-runner-nodejs
        - name: peertube-runner-cache
          mountPath: /home/peertube/.cache/peertube-runner-nodejs
    - name: peertube-runner-2
      image: owntube/peertube-runner:v603
      command: ["peertube-runner"]
      args: ["server", "--id", "peertube-runner-2"]
      volumeMounts:
        - name: peertube-runner-local
          mountPath: /home/peertube/.local/share/peertube-runner-nodejs
        - name: peertube-runner-config
          mountPath: /home/peertube/.config/peertube-runner-nodejs
        - name: peertube-runner-cache
          mountPath: /home/peertube/.cache/peertube-runner-nodejs
  volumes:
    - name: peertube-runner-local
      persistentVolumeClaim:
        claimName: peertube-runner-local
    - name: peertube-runner-config
      persistentVolumeClaim:
        claimName: peertube-runner-config
    - name: peertube-runner-cache
      persistentVolumeClaim:
        claimName: peertube-runner-cache
EOF
```

Get the pod's status and logs:

    kubectl get pods/peertube-runner-pod --namespace peertube -o wide
    kubectl logs peertube-runner-pod --namespace peertube

### Setup Step 3: Register the PeerTube Runner Servers with PeerTube Instances

For illustration, let us assume that you have a PeerTube v5.2 instance that you want to connect `"peertube-runner-1"`
to, and a PeerTube v6.0 instance that you want to connect `"peertube-runner-2"` to.

Get the URLs and the _Registration Tokens_ for each of the PeerTube instances and register via `peertube-runner` CLI:

```bash
export PT_v52_RUNNER=peertube-runner-1
export PT_v52_URL=https://my-peertube52.tv
export PT_v52_TOKEN=ptrrt-e6657119-a21d-4217-75d8-1b491da3a169
kubectl exec peertube-runner-pod --namespace peertube -- peertube-runner --id $PT_v52_RUNNER \
  register --url $PT_v52_URL --registration-token $PT_v52_TOKEN --runner-name my-$PT_v52_RUNNER \
  --runner-description="OwnTube-tv/peertube-runner project from @ar9708"
# Verify it is registered:
kubectl exec peertube-runner-pod --namespace peertube -- peertube-runner --id $PT_v52_RUNNER list-registered
'┌──────────────────────────┬──────────────────────┬─────────────────────────────────────────────────┐'
'│ instance                 │ runner name          │ runner description                              │'
'├──────────────────────────┼──────────────────────┼─────────────────────────────────────────────────┤'
'│ https://my-peertube52.tv │ my-peertube-runner-1 │ OwnTube-tv/peertube-runner project from @ar9708 │'
'└──────────────────────────┴──────────────────────┴─────────────────────────────────────────────────┘'
```

```bash
export PT_v60_RUNNER=peertube-runner-2
export PT_v60_URL=https://my-peertube60.tv
export PT_v60_TOKEN=ptrrt-23586320-b92e-4521-21f7-3b4e1dc2b952
kubectl exec peertube-runner-pod --namespace peertube -- peertube-runner --id $PT_v60_RUNNER \
  register --url $PT_v60_URL --registration-token $PT_v60_TOKEN --runner-name my-$PT_v60_RUNNER \
  --runner-description="OwnTube-tv/peertube-runner project from @ar9708"
# Verify it is registered:
kubectl exec peertube-runner-pod --namespace peertube -- peertube-runner --id $PT_v60_RUNNER list-registered
'┌──────────────────────────┬──────────────────────┬─────────────────────────────────────────────────┐'
'│ instance                 │ runner name          │ runner description                              │'
'├──────────────────────────┼──────────────────────┼─────────────────────────────────────────────────┤'
'│ https://my-peertube60.tv │ my-peertube-runner-2 │ OwnTube-tv/peertube-runner project from @ar9708 │'
'└──────────────────────────┴──────────────────────┴─────────────────────────────────────────────────┘'
```

Once transcoding starts being processed, you should find that there are a few files in the persistent storage, but they
are not expected to accumulate over time in terms of volume:

```plain
/mnt/hostpath-lv/
└── microk8s-hostpath
    ├── peertube-runner-cache-pvc-3f416610-c92f-4707-94b5-4d5b25e1a803
    │   ├── peertube-runner-1
    │   │   └── transcoding
    │   │       ├── c0eb39c6-ad46-4cb5-9267-fee2760e7c93
    │   │       └── fcef49bb-66d6-40d8-a955-b5429aa42b2c
    │   └── peertube-runner-2
    │       └── transcoding
    │           └── c9faa5c0-3da0-4b73-83ca-2ff80e07f465
    ├── peertube-runner-config-pvc-00652c44-d67b-4806-8c08-2865501e4c63
    │   ├── peertube-runner-1
    │   │   └── config.toml
    │   └── peertube-runner-2
    │       └── config.toml
    └── peertube-runner-local-pvc-4946ea42-767d-4b32-be07-de231a59071f
        ├── peertube-runner-1
        │   └── peertube-runner.sock
        └── peertube-runner-2
            └── peertube-runner.sock
```

## Contributing

Do you want to contribute something? Join us on GitHub [here](https://github.com/OwnTube-tv/peertube-runner) and open
an issue, or just fork it and play around.
