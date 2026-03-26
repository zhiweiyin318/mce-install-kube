package e2e

import (
	"fmt"

	"k8s.io/apimachinery/pkg/runtime/schema"

	apiextensionsclient "k8s.io/apiextensions-apiserver/pkg/client/clientset/clientset"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/controller-runtime/pkg/client/apiutil"

	addonclient "open-cluster-management.io/api/client/addon/clientset/versioned"
	clusterclient "open-cluster-management.io/api/client/cluster/clientset/versioned"
	operatorclient "open-cluster-management.io/api/client/operator/clientset/versioned"
	workv1client "open-cluster-management.io/api/client/work/clientset/versioned"
)

var (
	hubKubeConfig string
)

var (
	HubClients        *Clients
	HostedClusterName string
)

const (
	LocalClusterName                   = "local-cluster"
	ConfigPolicyAddonName              = "config-policy-controller"
	GovernancePolicyFrameworkAddonName = "governance-policy-framework"
	HypershiftAddonName                = "hypershift-addon"
	WorkManagerAddonName               = "work-manager"
	MCEName                            = "multiclusterengine"
)

var (
	MCEGVR           = schema.GroupVersionResource{Group: "multicluster.openshift.io", Version: "v1", Resource: "multiclusterengines"}
	ClusterInfoGVR   = schema.GroupVersionResource{Group: "internal.open-cluster-management.io", Version: "v1beta1", Resource: "managedclusterinfos"}
	HostedClusterGVR = schema.GroupVersionResource{Group: "hypershift.openshift.io", Version: "v1beta1", Resource: "hostedclusters"}
)

type Clients struct {
	KubeClient          kubernetes.Interface
	APIExtensionsClient apiextensionsclient.Interface
	OperatorClient      operatorclient.Interface
	ClusterClient       clusterclient.Interface
	WorkClient          workv1client.Interface
	AddonClient         addonclient.Interface
	DynamicClient       dynamic.Interface
	RestMapper          meta.RESTMapper
}

func NewClients(clusterCfg *rest.Config) (*Clients, error) {
	kubeClient, err := kubernetes.NewForConfig(clusterCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster client: %w", err)
	}

	httpClient, err := rest.HTTPClientFor(clusterCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster http client: %w", err)
	}

	restMapper, err := apiutil.NewDynamicRESTMapper(clusterCfg, httpClient)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster rest mapper: %w", err)
	}

	dynamicClient, err := dynamic.NewForConfig(clusterCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster dynamic client: %w", err)
	}

	apiExtensionsClient, err := apiextensionsclient.NewForConfig(clusterCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster api extensions client: %w", err)
	}

	operatorClient, err := operatorclient.NewForConfig(clusterCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster operator client: %w", err)
	}

	clusterClient, err := clusterclient.NewForConfig(clusterCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster cluster client: %w", err)
	}

	workClient, err := workv1client.NewForConfig(clusterCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster work client: %w", err)
	}

	addonClient, err := addonclient.NewForConfig(clusterCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create managed cluster addon client: %w", err)
	}

	return &Clients{
		KubeClient:          kubeClient,
		APIExtensionsClient: apiExtensionsClient,
		OperatorClient:      operatorClient,
		ClusterClient:       clusterClient,
		WorkClient:          workClient,
		AddonClient:         addonClient,
		DynamicClient:       dynamicClient,
		RestMapper:          restMapper,
	}, nil
}
