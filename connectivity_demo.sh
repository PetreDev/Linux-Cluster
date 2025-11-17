#!/bin/bash

# Author: Petre Temelko <petre.temelko@student.um.si>

# Connectivity Demonstration Script
# Shows SSH connectivity between all combinations of cluster instances

# Check if N is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <N>"
    echo "Where N is the number of instances in the cluster"
    exit 1
fi

N=$1

# Validate N
if ! [[ "$N" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: N must be a positive integer"
    exit 1
fi

# Define variables
SSH_USER="student"
KEY_NAME="id_rsa_cluster"
PRIVATE_KEY="./${KEY_NAME}"

echo "=== Cluster Connectivity Demonstration (N=$N) ==="

# Function to generate host list for pssh (all comps except the source)
generate_host_list() {
    local source_comp=$1
    local hosts=""
    for ((i=1; i<=N; i++)); do
        if [ $i -ne $source_comp ]; then
            hosts="${hosts} -H comp${i}"
        fi
    done
    echo "$hosts"
}

# Test connectivity from host to each container
echo "=== Testing Host to Container Connectivity ==="
for ((i=1; i<=N; i++)); do
    HOST_PORT=$((i + 2221))
    echo "Testing connection to comp${i} (port ${HOST_PORT})..."
    if ssh -i "${PRIVATE_KEY}" -p "${HOST_PORT}" "${SSH_USER}@localhost" "echo 'Connection successful: \$(hostname) - \$(hostname -i)'" 2>/dev/null; then
        echo "✓ Host -> comp${i} connection OK"
    else
        echo "✗ Host -> comp${i} connection FAILED"
    fi
    echo ""
done

# Test inter-container connectivity using nested SSH calls
echo "=== Testing Inter-Container Connectivity (All Combinations) ==="
for ((source=1; source<=N; source++)); do
    SOURCE_HOST_PORT=$((source + 2221))

    echo "Testing from comp${source} to other containers..."

    # Build the list of target hosts for pssh
    TARGET_HOSTS=""
    for ((target=1; target<=N; target++)); do
        if [ $target -ne $source ]; then
            TARGET_HOSTS="${TARGET_HOSTS} -H comp${target}"
        fi
    done

    if [ -n "$TARGET_HOSTS" ]; then
        echo "Command: ssh comp${source} parallel-ssh -i $TARGET_HOSTS hostname -i"

        # Execute the nested SSH command
        ssh -i "${PRIVATE_KEY}" -p "${SOURCE_HOST_PORT}" "${SSH_USER}@localhost" \
            "parallel-ssh -i $TARGET_HOSTS hostname -i"

        echo ""
    fi
done

echo "=== Connectivity demonstration complete ==="
