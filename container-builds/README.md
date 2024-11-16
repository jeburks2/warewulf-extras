# Makefile Container building

This is designed around the podman build system, but could be adapted to work with apptainer or docker

There are several assumptions made about where repo information lives. 
Change the appropriate variables in the Makefile. This also assumes that podman is only used to build containers on your system. 

This will solve the sync-user issue by removing /etc/passwd and /etc/group from inside the container, and copies them in from the host

This will automatically download the declared NVIDIA Driver, but you will have to supply the MLX driver yourself in a directory called mlx.

To build all containers, simply type

```
make
```

### Building Multi-Arch Containers
To build for differnt cpu architectures, you will need to ensure QEMU is setup 

`sudo podman run --rm --privileged multiarch/qemu-user-static --reset -p yes`

More informaiton in the official [Warewulf documentaion](https://warewulf.org/docs/v4.5.x/contents/containers.html#multi-arch-container-management)

## Cleanup
Running `make clean` will clear temp files generated during the build process and unused podman images. This is probably safe to run on most systems

Running `make veryclean` will also delete any tar files in the current directory, forcibly remove oci blobs from the system, and reset podman. This may be destructive on your system if you have containers running with podman.