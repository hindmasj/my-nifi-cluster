# Some Maintenance Routines

## Build NAR

```
mvn clean install
```

## Docker

### Daemon Connection

If you see ``ERROR: Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?``

Look at [Docker On WSL](https://docs.docker.com/desktop/windows/wsl/#enabling-docker-support-in-wsl-2-distros)

### Refresh Pulled Images

```
docker-compose pull
```

### Build Custom Image

```
docker-compose build
```

### Push Built Image

#### First Time

1. Go to [Docker Hub](https://hub.docker.com/)
1. Sign in.
1. Create repository.

#### Push

```
docker login --username <username>
docker image tag my-nifi-cluster-nifi:latest <username>/<reponame>
docker push <username>/<reponame>
```