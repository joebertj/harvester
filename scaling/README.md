# Scaling App Dockerization

Before you run the build script (`build-and-push.sh`), note a small tweak made for Harbor compatibility!

Harbor uses a strict `host/project/image` structure for its repositories, and by default, it expects public images to go into the builtin `library` project namespace.

`scaling/build-and-push.sh` and the Kubernetes scaling YAMLs have been updated to use the exact Harbor-compliant image path: 
`registry.home.kenchlightyear.com/library/scaling-fastapi:latest`

An automatic `docker login` is included at the top of the `build-and-push.sh` script. It securely fetches the auto-generated Harbor admin password directly from the Kubernetes Secret (which was synced from Vault) and authenticates for you.
