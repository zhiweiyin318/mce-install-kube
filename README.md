# mce-install-kube
The manifests of add-ons or components deployed on k8s platform like AKS etc.

# Prerequisites

The MCE operator is required to be installed on the Hub cluster. 

[Here](configuration/multiclusterengine.yaml) is the MCE CR sample.

# Configure the MCE 

1. Apply the `KlusterletConfig` for hosted cluster importing.

```
kubectl apply -f ./configuration/klusterletconfig.yaml
```

2. Apply a `AddOnDeploymentConfig` for add-ons working in hosted mode.

```
kubectl apply -f ./configuration/addonhostedconfig.yaml
```

3. Patch work-manager add-on to support hosted mode.
   
```
kubectl patch clustermanagementaddon work-manager --type merge -p '{"spec":{"supportedConfigs":[{"defaultConfig":{"name":"addon-hosted-config","namespace":"multicluster-engine"},"group":"addon.open-cluster-management.io","resource":"addondeploymentconfigs"}]}}'
```
or

```
kubectl apply -f ./configuration/workmanagercma.yaml
```
# Install Policy after MCE is installed

```
helm install policy ./policy
```


# E2e tets

Set environment variables and run tests.

```bash
# the kubeconfig file of Hub cluster
export KUBECONFIG=<your hub cluster kubeconfig file>
# will skip the tests on managed cluster if MANAGED_CLUSTER_NAME is empty.
export MANAGED_CLUSTER_NAME="<cluster name>"

make test-e2e
```
