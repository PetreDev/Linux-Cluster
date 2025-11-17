#!/bin/bash

# Author: Petre Temelko <petre.temelko@student.um.si>
# Cleanup script for N02 Linux Cluster

echo "=== Cleaning up N02 Linux Cluster ==="

echo "Stopping and removing all comp* containers..."
# Stop all containers whose names start with "comp"
docker stop $(docker ps -aq --filter "name=comp") 2>/dev/null || true
# Remove all containers whose names start with "comp"
docker rm $(docker ps -aq --filter "name=comp") 2>/dev/null || true

echo "Removing Docker network..."
docker network rm cluster-network 2>/dev/null || true

echo "Removing Docker image..."
docker rmi linux-ssh-server 2>/dev/null || true

echo "Removing SSH keys..."
rm -f id_rsa_cluster id_rsa_cluster.pub

echo "Removing generated files..."
rm -f Dockerfile

echo "Removing temporary files..."
rm -f /tmp/cluster_known_hosts*

echo "Restoring host SSH known_hosts..."
# Find and restore the most recent backup if it exists
LATEST_BACKUP=$(ls -t ~/.ssh/known_hosts.backup.* 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
    mv "$LATEST_BACKUP" ~/.ssh/known_hosts
    echo "Restored known_hosts from backup"
else
    # Remove all cluster-related entries from known_hosts if no backup exists
    if [ -f ~/.ssh/known_hosts ]; then
        # Remove localhost:222* entries (host-to-container)
        sed -i '/^\[localhost\]:222[0-9]/d' ~/.ssh/known_hosts
        # Remove any comp* hostname entries that might have been added
        sed -i '/^comp[0-9]/d' ~/.ssh/known_hosts
        # Remove IP entries in the cluster range
        sed -i '/^172\.20\.0\./d' ~/.ssh/known_hosts
        echo "Removed all cluster entries from known_hosts"
    fi
fi

echo "=== Cleanup complete ==="
echo "All cluster containers, networks, images, keys, and temporary files have been removed."