#!/bin/bash

# Configuration
CLUSTERS=("cluster1.example.com" "cluster2.example.com")  # List your OpenShift clusters here
NAMESPACE="ibm-spectrum-scale"
SERVICE_ACCOUNT="check-gpfs-sa"  # Service account with permissions to exec into the pods
EMAIL_RECIPIENT="admin@example.com"  # Email to send alerts to

# Function to log into an OpenShift cluster
login_to_cluster() {
    local cluster=$1
    # Add the login command here, such as using a kubeconfig or a token for each cluster.
    # Example: oc login --token=<token> --server=https://$cluster
    echo "Logging into cluster $cluster..."
    oc login --server="https://$cluster" --token="your_token_here"
    if [ $? -ne 0 ]; then
        echo "Failed to log into cluster $cluster"
        return 1
    fi
    return 0
}

# Function to check the GPFS status and send alerts if needed
check_gpfs_status() {
    local pod=$1
    local namespace=$2

    # Check GPFS state with mmgetstate -a
    gpfs_state=$(oc exec $pod -n $namespace -- mmgetstate -a 2>&1)
    if echo "$gpfs_state" | grep -q "inactive"; then
        echo "GPFS state is inactive on pod $pod"
        echo "GPFS state is inactive on pod $pod in namespace $namespace" | mail -s "ALERT: GPFS Inactive" $EMAIL_RECIPIENT
    fi

    # Check GPFS health with mmhealth cluster show
    gpfs_health=$(oc exec $pod -n $namespace -- mmhealth cluster show 2>&1)
    if echo "$gpfs_health" | grep -q "degraded"; then
        echo "GPFS health is degraded on pod $pod"
        echo "GPFS health is degraded on pod $pod in namespace $namespace" | mail -s "ALERT: GPFS Health Degraded" $EMAIL_RECIPIENT
    fi
}

# Main script
for cluster in "${CLUSTERS[@]}"; do
    if login_to_cluster "$cluster"; then
        # Find all pods in the ibm-spectrum-scale namespace with "compute" in their names
        echo "Checking GPFS status on cluster $cluster..."
        compute_pods=$(oc get pods -n $NAMESPACE -o name | grep compute)

        for pod in $compute_pods; do
            pod_name=$(echo "$pod" | sed 's/pod\///')
            echo "Checking GPFS status on pod $pod_name in cluster $cluster..."
            check_gpfs_status "$pod_name" "$NAMESPACE"
        done
    else
        echo "Skipping cluster $cluster due to login failure."
    fi
done

# Log out from OpenShift cluster (optional, if tokens are short-lived or if cleanup is needed)
oc logout

