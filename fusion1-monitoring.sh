	#!/bin/bash

# Configuration
CLUSTERS=("https://cluster1.example.com" "https://cluster2.example.com")  # OpenShift cluster API URLs
NAMESPACE="ibm-spectrum-scale"
EMAIL="admin@example.com"  # Email for alerts

# Function to log into the OpenShift cluster
login_cluster() {
    local cluster=$1
    echo "Logging into $cluster..."
    oc login --server="$cluster" --token="your_token_here"
}

# Function to check GPFS status in each pod
check_gpfs_in_pod() {
    local pod=$1
    echo "Checking GPFS in pod $pod..."

    # Check GPFS state
    if oc exec $pod -n $NAMESPACE -- mmgetstate -a | grep -q "inactive"; then
        echo "Alert: GPFS state is inactive in $pod" | mail -s "GPFS Inactive Alert" $EMAIL
    fi

    # Check GPFS health
    if oc exec $pod -n $NAMESPACE -- mmhealth cluster show | grep -q "degraded"; then
        echo "Alert: GPFS health is degraded in $pod" | mail -s "GPFS Health Degraded Alert" $EMAIL
    fi
}

# Main script
for cluster in "${CLUSTERS[@]}"; do
    login_cluster "$cluster"

    # Find and check each compute pod in the namespace
    for pod in $(oc get pods -n $NAMESPACE -o name | grep "compute"); do
        check_gpfs_in_pod "$pod"
    done

    oc logout  # Logout after checking each cluster
done

