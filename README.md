# N02 Linux Cluster Setup

A Docker-based Linux cluster setup script that creates N SSH-enabled Ubuntu containers with full network connectivity for distributed computing experiments and testing.

## Overview

This project automates the creation of a Linux cluster using Docker containers. Each container runs Ubuntu 22.04 with OpenSSH server, and they're all connected through a custom Docker network with SSH key authentication configured for seamless connectivity between containers and from the host machine.

## Features

- **Automated Setup**: Single command creates N container instances
- **SSH Connectivity**: Bidirectional SSH access between all containers and host
- **Custom Networking**: Isolated Docker network with static IP assignments
- **Key Management**: Automatic SSH key pair generation and distribution
- **Parallel SSH**: Includes `pssh` for parallel command execution across the cluster
- **Connectivity Testing**: Built-in demonstration script to verify cluster connectivity
- **Easy Cleanup**: Complete removal of all cluster resources

## Architecture

```
Host Machine
├── SSH Key Pair (id_rsa_cluster, id_rsa_cluster.pub)
├── Docker Network (cluster-network: 172.20.0.0/16)
└── N Container Instances (comp1, comp2, ..., compN)
    ├── Ubuntu 22.04 + OpenSSH
    ├── Static IP (172.20.0.11, 172.20.0.12, ...)
    ├── Mapped SSH ports (2222, 2223, ..., 2221+N)
    ├── SSH key authentication
    └── Hostname resolution (/etc/hosts updated)
```

## Prerequisites

- **Docker**: Must be installed and running on your system
- **Bash**: Unix-like shell environment
- **SSH client**: For connecting to containers

### Verify Prerequisites

```bash
# Check Docker installation
docker --version

# Check Docker daemon
docker info

# Verify Docker can run containers
docker run hello-world
```

## Quick Start

1. **Clone or download the project files**

2. **Make scripts executable** (if not already):
   ```bash
   chmod +x N02.sh connectivity_demo.sh cleanup.sh
   ```

3. **Create a 3-node cluster**:
   ```bash
   ./N02.sh 3
   ```

4. **Test connectivity**:
   ```bash
   ./connectivity_demo.sh 3
   ```

5. **Connect to containers**:
   ```bash
   # SSH to comp1 from host
   ssh -i id_rsa_cluster student@localhost -p 2222

   # SSH between containers (from comp1 to comp2)
   ssh student@comp2
   ```

6. **Clean up when done**:
   ```bash
   ./cleanup.sh
   ```

## Detailed Usage

### Creating the Cluster

```bash
./N02.sh <N>
```

Where `<N>` is the number of container instances to create (must be a positive integer).

**Example Output**:
```
Setting up 3 SSH Virtual Environment instances
=== Step 1: Create Dockerfile ===
Dockerfile created.
=== Step 2: Build Docker image ===
[+] Building 2.1s
...
=== Step 3: Create Docker network ===
Docker network 'cluster-network' created.
=== Step 4: Generate SSH key pair ===
SSH key pair generated.
=== Step 5: Create 3 container instances ===
Creating container comp1 with IP 172.20.0.11 on host port 2222
...
=== Cluster Setup Complete ===
Created 3 container instances:
  comp1: IP=172.20.0.11, Host Port=2222
  comp2: IP=172.20.0.12, Host Port=2223
  comp3: IP=172.20.0.13, Host Port=2224

SSH connection commands:
# Connect from host to containers:
ssh -i id_rsa_cluster student@localhost -p 2222
ssh -i id_rsa_cluster student@localhost -p 2223
ssh -i id_rsa_cluster student@localhost -p 2224

# Connect between containers:
# From container comp1: ssh student@comp2
# Or using IPs: ssh student@172.20.0.12
```

### Connectivity Testing

```bash
./connectivity_demo.sh <N>
```

This script tests:
- Host-to-container connectivity for all instances
- Inter-container connectivity using parallel SSH (pssh)

**Example Output**:
```
=== Cluster Connectivity Demonstration (N=3) ===
=== Testing Host to Container Connectivity ===
Testing connection to comp1 (port 2222)...
Connection successful: comp1 - 172.20.0.11
✓ Host -> comp1 connection OK

Testing connection to comp2 (port 2223)...
Connection successful: comp2 - 172.20.0.12
✓ Host -> comp2 connection OK
...
=== Testing Inter-Container Connectivity (All Combinations) ===
Testing from comp1 to other containers...
Command: ssh comp1 parallel-ssh -i -O StrictHostKeyChecking=no -O UserKnownHostsFile=/dev/null -H comp2 -H comp3 hostname -i
comp2: 172.20.0.12
comp3: 172.20.0.13
...
```

### Connecting to Containers

#### From Host to Container
```bash
ssh -i id_rsa_cluster student@localhost -p <port>
```

Ports are assigned sequentially starting from 2222:
- comp1: port 2222
- comp2: port 2223
- comp3: port 2224
- etc.

#### Between Containers
Once inside any container, you can SSH to other containers by hostname:
```bash
# From comp1 to comp2
ssh student@comp2

# From comp1 to comp3
ssh student@comp3
```

### Parallel Command Execution

Each container has `pssh` (parallel SSH) installed for running commands across multiple containers:

```bash
# From inside any container, run 'hostname' on all other containers
parallel-ssh -i -H comp2 -H comp3 hostname

# Run a custom command on multiple containers
parallel-ssh -i -H comp2 -H comp3 "echo 'Hello from \$(hostname)'"
```

### Cleanup

```bash
./cleanup.sh
```

This removes:
- All `comp*` containers
- The `cluster-network` Docker network
- The `linux-ssh-server` Docker image
- SSH key files (`id_rsa_cluster`, `id_rsa_cluster.pub`)
- Generated `Dockerfile`

## Configuration

The scripts use these default configurations (can be modified in the source):

| Setting | Default Value | Description |
|---------|---------------|-------------|
| `IMAGE_NAME` | `linux-ssh-server` | Docker image name |
| `SSH_USER` | `student` | SSH username for containers |
| `KEY_NAME` | `id_rsa_cluster` | SSH key filename |
| `NETWORK_NAME` | `cluster-network` | Docker network name |
| `SUBNET` | `172.20.0.0/16` | Network subnet |
| `GATEWAY` | `172.20.0.1` | Network gateway |

## Use Cases

This cluster setup is ideal for:

- **Distributed Systems Learning**: Practice with parallel computing, load balancing, and distributed algorithms
- **DevOps Training**: Test configuration management, deployment strategies, and monitoring tools
- **Network Testing**: Experiment with networking concepts, firewalls, and security configurations
- **Software Development**: Test applications that require multiple nodes or network communication
- **Educational Labs**: Create consistent environments for computer science coursework

## Troubleshooting

### Common Issues

1. **Permission denied (publickey)**:
   - Ensure you're using the correct SSH key: `-i id_rsa_cluster`
   - Check that the key file has correct permissions: `chmod 600 id_rsa_cluster`

2. **Connection refused**:
   - Wait a few seconds after cluster creation for containers to fully start
   - Verify Docker daemon is running: `docker info`

3. **Network connectivity issues**:
   - Ensure no firewall is blocking the mapped ports (2222+)
   - Check container status: `docker ps`

4. **Container fails to start**:
   - Check available resources: `docker system df`
   - Clean up previous runs: `./cleanup.sh`

### Debug Commands

```bash
# Check container status
docker ps -a --filter "name=comp"

# View container logs
docker logs comp1

# Access container shell directly
docker exec -it comp1 /bin/bash

# Check network configuration
docker network inspect cluster-network
```

## Security Notes

- SSH keys are generated automatically and stored in the current directory
- All containers use the same SSH key pair for simplicity (not recommended for production)
- No password authentication is configured
- Containers run with default Ubuntu user permissions

## Author

**Petre Temelko**
- Student ID: petre.temelko@student.um.si
- Project: N02 Linux Cluster Setup

## License

This project is provided as-is for educational purposes.
