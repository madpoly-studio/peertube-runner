# `owntube/peertube-runner`

Containerized [@peertube/peertube-runner](https://www.npmjs.com/package/@peertube/peertube-runner) for remote execution of transcoding jobs in Kubernetes.

## `owntube/peertube-runner:v521` PeerTube v5.2.1 Runner

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

## `owntube/peertube-runner:v603` PeerTube v6.0.3 Runner

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
