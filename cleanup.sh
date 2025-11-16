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

echo "=== Cleanup complete ==="
echo "All cluster containers, networks, images, and keys have been removed."