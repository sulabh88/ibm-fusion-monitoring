#!/bin/bash

# Configuration
CLUSTERS=("https://cluster1.example.com" "https://cluster2.example.com")  # OpenShift cluster API URLs
NAMESPACE="ibm-spectrum-scale"
EMAIL="admin@example.com"  # Email for alerts
KUBEADMIN_USER="kubeadmin"  # OpenShift admin user
KUBEADMIN_PASS="your_kubeadmin_password"  # Replace with the actual kubeadmin password

# Function to log into the OpenShift cluster using kubeadmin credentials
login_cluster() {
    local cluster=$1
    echo "Logging into $cluster with kubeadmin..."
    oc login --server="$cluster" -u "$KUBEADMIN_USER" -p "$KUBEADMIN_PASS"
    if [ $? -ne 0 ]; then
        echo "Failed to log into $cluster."
        return 1
    fi
    return 0
}

# Function to check GPFS status in a single compute pod
check_gpfs_in_one_pod() {
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
    if login_cluster "$cluster"; then
        # Find one compute pod in the namespace and check it
        pod=$(oc get pods -n $NAMESPACE -o name | grep "compute" | head -n 1)
        if [ -n "$pod" ]; then
            check_gpfs_in_one_pod "$pod"
        else
            echo "No compute pods found in $NAMESPACE namespace on $cluster."
        fi
        # Logout from the cluster
        oc logout
    fi
done

# Clear kubeadmin credentials
unset KUBEADMIN_USER
unset KUBEADMIN_PASS
echo "Kubeadmin credentials have been removed from memory."

