#!/bin/bash

# Author: Petre Temelko <petre.temelko@student.um.si>

# N02: Linux Cluster Setup Script
# Creates N instances of SSH-enabled containers with networking

# Check if N is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <N>"
    echo "Where N is the number of instances to create"
    exit 1
fi

N=$1

# Validate N is a positive integer
if ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: N must be a positive integer"
    exit 1
fi

echo "Setting up $N SSH Virtual Environment instances"

# Define variables
IMAGE_NAME="linux-ssh-server"
SSH_USER="student"
KEY_NAME="id_rsa_cluster"
PRIVATE_KEY="./${KEY_NAME}"
PUBLIC_KEY="./${KEY_NAME}.pub"
NETWORK_NAME="cluster-network"
SUBNET="172.20.0.0/16"
GATEWAY="172.20.0.1"

echo "=== Step 1: Create Dockerfile ==="

cat > Dockerfile << EOF
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \\
    apt-get install -y openssh-server sudo pssh && \\
    mkdir -p /var/run/sshd && \\
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash ${SSH_USER} && \\
    mkdir -p /home/${SSH_USER}/.ssh && \\
    chown -R ${SSH_USER}:${SSH_USER} /home/${SSH_USER}

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
EOF

echo "Dockerfile created."

echo "=== Step 2: Build Docker image ==="
docker build -t "${IMAGE_NAME}" .
echo "Docker image '${IMAGE_NAME}' built."

echo "=== Step 3: Create Docker network ==="
# Remove existing network if it exists
docker network rm "${NETWORK_NAME}" &>/dev/null || true
docker network create --subnet="${SUBNET}" --gateway="${GATEWAY}" "${NETWORK_NAME}"
echo "Docker network '${NETWORK_NAME}' created."

echo "=== Step 4: Generate SSH key pair ==="
if [ ! -f "${PRIVATE_KEY}" ]; then
    ssh-keygen -t rsa -b 4096 -f "${PRIVATE_KEY}" -N "" -C "cluster-ssh-key"
fi
chmod 600 "${PRIVATE_KEY}"
echo "SSH key pair generated."

echo "=== Step 5: Create $N container instances ==="
declare -a CONTAINER_NAMES
declare -a CONTAINER_IPS
declare -a HOST_PORTS

for ((i=1; i<=N; i++)); do
    CONTAINER_NAME="comp${i}"
    IP_ADDR="172.20.0.$(($i + 10))"  # Start from 172.20.0.11
    HOST_PORT="$(($i + 2221))"  # Start from 2222

    CONTAINER_NAMES[$i]="${CONTAINER_NAME}"
    CONTAINER_IPS[$i]="${IP_ADDR}"
    HOST_PORTS[$i]="${HOST_PORT}"

    echo "Creating container ${CONTAINER_NAME} with IP ${IP_ADDR} on host port ${HOST_PORT}"

    # Stop and remove existing container if it exists
    docker stop "${CONTAINER_NAME}" &>/dev/null || true
    docker rm "${CONTAINER_NAME}" &>/dev/null || true

    # Run container with custom networking
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --hostname "${CONTAINER_NAME}" \
        --network "${NETWORK_NAME}" \
        --ip "${IP_ADDR}" \
        -p "${HOST_PORT}":22 \
        "${IMAGE_NAME}"

    echo "Container ${CONTAINER_NAME} started."
done

echo "=== Step 6: Setup SSH keys and hostnames ==="
# Wait for containers to start
sleep 5

# Create hosts file content for each container
HOSTS_CONTENT=""
for ((i=1; i<=N; i++)); do
    HOSTS_CONTENT="${HOSTS_CONTENT}${CONTAINER_IPS[$i]} ${CONTAINER_NAMES[$i]}\n"
done

# Setup each container
for ((i=1; i<=N; i++)); do
    CONTAINER_NAME="${CONTAINER_NAMES[$i]}"

    echo "Setting up ${CONTAINER_NAME}..."

    # Copy public key to container
    docker cp "${PUBLIC_KEY}" "${CONTAINER_NAME}":/home/"${SSH_USER}"/.ssh/authorized_keys
    docker exec "${CONTAINER_NAME}" chown "${SSH_USER}:${SSH_USER}" /home/"${SSH_USER}"/.ssh/authorized_keys
    docker exec "${CONTAINER_NAME}" chmod 600 /home/"${SSH_USER}"/.ssh/authorized_keys

    # Copy private key to container for SSH between containers
    docker cp "${PRIVATE_KEY}" "${CONTAINER_NAME}":/home/"${SSH_USER}"/.ssh/id_rsa
    docker exec "${CONTAINER_NAME}" chown "${SSH_USER}:${SSH_USER}" /home/"${SSH_USER}"/.ssh/id_rsa
    docker exec "${CONTAINER_NAME}" chmod 600 /home/"${SSH_USER}"/.ssh/id_rsa

    # Update /etc/hosts for internal networking
    echo -e "${HOSTS_CONTENT}" | docker exec -i "${CONTAINER_NAME}" sh -c 'cat >> /etc/hosts'

    echo "${CONTAINER_NAME} setup complete."
done

echo "=== Step 7: Setup SSH known_hosts for seamless connectivity ==="
# Create a temporary known_hosts file with all container keys
KNOWN_HOSTS_FILE="/tmp/cluster_known_hosts"
rm -f "${KNOWN_HOSTS_FILE}"

# Scan SSH keys for all containers
for ((i=1; i<=N; i++)); do
    CONTAINER_NAME="${CONTAINER_NAMES[$i]}"
    CONTAINER_IP="${CONTAINER_IPS[$i]}"

    echo "Scanning SSH keys for ${CONTAINER_NAME}..."

    # Get SSH host key from container
    HOST_KEY=$(docker exec "${CONTAINER_NAME}" ssh-keygen -f /etc/ssh/ssh_host_rsa_key -y 2>/dev/null)
    if [ -n "${HOST_KEY}" ]; then
        # Add both hostname and IP entries
        echo "${CONTAINER_NAME} ${HOST_KEY}" >> "${KNOWN_HOSTS_FILE}"
        echo "${CONTAINER_IP} ${HOST_KEY}" >> "${KNOWN_HOSTS_FILE}"

        # Also add comp1, comp2, etc. hostname format
        echo "comp${i} ${HOST_KEY}" >> "${KNOWN_HOSTS_FILE}"
    fi
done

# Copy known_hosts to all containers
for ((i=1; i<=N; i++)); do
    CONTAINER_NAME="${CONTAINER_NAMES[$i]}"
    echo "Installing known_hosts in ${CONTAINER_NAME}..."
    docker cp "${KNOWN_HOSTS_FILE}" "${CONTAINER_NAME}":/home/"${SSH_USER}"/.ssh/known_hosts
    docker exec "${CONTAINER_NAME}" chown "${SSH_USER}:${SSH_USER}" /home/"${SSH_USER}"/.ssh/known_hosts
done

# Also setup host known_hosts for localhost:port connections
echo "Setting up host known_hosts for localhost connections..."
HOST_KNOWN_HOSTS="${HOME}/.ssh/known_hosts"
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

# Backup existing known_hosts if it exists
if [ -f "${HOST_KNOWN_HOSTS}" ]; then
    cp "${HOST_KNOWN_HOSTS}" "${HOST_KNOWN_HOSTS}.backup.$(date +%s)" 2>/dev/null || true
fi

# Add container keys to host known_hosts for localhost:port access
for ((i=1; i<=N; i++)); do
    CONTAINER_NAME="${CONTAINER_NAMES[$i]}"
    HOST_PORT="$(($i + 2221))"

    # Get SSH host key from container
    HOST_KEY=$(docker exec "${CONTAINER_NAME}" ssh-keygen -f /etc/ssh/ssh_host_rsa_key -y 2>/dev/null)
    if [ -n "${HOST_KEY}" ]; then
        # Remove any existing entry for this localhost:port first
        ssh-keygen -f "${HOST_KNOWN_HOSTS}" -R "[localhost]:${HOST_PORT}" >/dev/null 2>&1 || true
        # Add localhost:port entry to host known_hosts
        echo "[localhost]:${HOST_PORT} ${HOST_KEY}" >> "${HOST_KNOWN_HOSTS}"
    fi
done

# Cleanup
rm -f "${KNOWN_HOSTS_FILE}"

echo ""
echo "=== Cluster Setup Complete ==="
echo "Created $N container instances:"
for ((i=1; i<=N; i++)); do
    echo "  ${CONTAINER_NAMES[$i]}: IP=${CONTAINER_IPS[$i]}, Host Port=${HOST_PORTS[$i]}"
done

echo ""
echo "SSH connection commands:"
echo "# Connect from host to containers:"
for ((i=1; i<=N; i++)); do
    echo "ssh -i ${PRIVATE_KEY} ${SSH_USER}@localhost -p ${HOST_PORTS[$i]}"
done

echo ""
echo "# Connect between containers:"
echo "# From container comp1: ssh ${SSH_USER}@comp2"
echo "# Or using IPs: ssh ${SSH_USER}@${CONTAINER_IPS[2]}"

echo ""
echo "To test connectivity, run the demonstration script:"
echo "./connectivity_demo.sh $N"