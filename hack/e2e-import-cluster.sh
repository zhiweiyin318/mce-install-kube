#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# env
# export KUBECONFIG=kubeconfig
# export MANAGED_KUBECONFIG=managed-kubeconfig
# export EXTERNAL_MANAGED_KUBECONFIG=external-managed-kubeconfig
# export MANAGED_CLUSTER_NAME=spoke

KLUSTERLET_NS=klusterlet-$MANAGED_CLUSTER_NAME

function waitForReady() {
    FOUND=1
    SECOND=0
    local cmd="$1"
    local rst="$2"

    echo "check if \"$cmd\" ==  $rst"

    while [ ${FOUND} -eq 1 ]; do
        if [ $SECOND -gt 240 ]; then
            echo "Timeout waiting for the result of cmd. "
        
            kubectl get pods -A
            kubectl get mcl
            kubectl get mce multiclusterengine -o yaml
  
            exit 1
        fi

        result=$(bash -c "$cmd" 2>/dev/null || true) 
        if [ "$rst" -eq "$result" ]; then
            echo "pass "
            break
        fi
        
        echo "expected $rst, but got $result, re-try after 5 seconds..."
        sleep 5
        (( SECOND = SECOND + 5 ))
    done
}


echo ""
echo "###### Create managed cluster ns ###### "
result=$(kubectl get ns | grep -c $MANAGED_CLUSTER_NAME  2>/dev/null || true)
if [ $result -eq 0 ] ; then 
kubectl create ns $MANAGED_CLUSTER_NAME; 
fi

echo ""
echo "###### Create auto-import secret"
result=$(kubectl get secret -n $MANAGED_CLUSTER_NAME | grep -c auto-import-secret  2>/dev/null || true)
if [ $result -eq 0 ]; then 
  kubectl create secret generic auto-import-secret --from-file=kubeconfig=$MANAGED_KUBECONFIG -n $MANAGED_CLUSTER_NAME
fi

echo ""
echo "###### Create managedCluster ######"
cat << EOF | kubectl apply -f -
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: $MANAGED_CLUSTER_NAME
  annotations:
    import.open-cluster-management.io/klusterlet-deploy-mode: Hosted
    import.open-cluster-management.io/hosting-cluster-name: local-cluster
    addon.open-cluster-management.io/enable-hosted-mode-addons: "true"
    open-cluster-management/created-via: other
  labels:
    cluster.open-cluster-management.io/clusterset: default
    vendor: OpenShift
spec:
  hubAcceptsClient: true
  leaseDurationSeconds: 60
EOF

echo ""
echo "###### Create external-managed-kubeconfig secret ######"
waitForReady "kubectl get ns | grep -c \"klusterlet-$MANAGED_CLUSTER_NAME\"" 1
result=$(kubectl get secret -n $KLUSTERLET_NS | grep -c external-managed-kubeconfig  2>/dev/null || true)
if [ $result -eq 0 ]; then 
  kubectl create secret generic external-managed-kubeconfig --from-file=kubeconfig=$EXTERNAL_MANAGED_KUBECONFIG -n $KLUSTERLET_NS
fi

echo ""
echo "###### Wait for $MANAGED_CLUSTER_NAME is ready ######"
waitForReady "kubectl get mcl $MANAGED_CLUSTER_NAME | grep -c \"True\"" 1

echo ""
echo "###### Wait unitl 3 addons in $MANAGED_CLUSTER_NAME is Available ######"
waitForReady "kubectl get mca -n $MANAGED_CLUSTER_NAME | grep -c \"True\"" 3

echo ""
echo "!!!!!!!!!! hosted cluster $MANAGED_CLUSTER_NAME is imported succussfully !!!!!!!!!!!!"
echo ""
