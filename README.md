# formula_portainer_container

This is an early proof-of-concept for using a SaltStack state to create a docker container via the Portainer API.

## What works
* The required image is pulled form Docker Hub.
* The container is created (but not started).

## What doesn't work
* We don't currently detect if the container is already running properly.  We currently assume it is running and don't start it.
* The Docker endpoint ID is hard coded.  We should autodetect a default and override this default with a pillar.
* Only containers are supported, not stacks (yet?).

## What needs improvement
* The Portainer login credentials are specified in init.sls.  This should be moved into a secure pillar.
* Docker Hub credentails are not used, even if they are configured in Portainer.
