package e2e

import (
	"context"
	"fmt"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/rand"
)

var _ = Describe("Check the status of hosted cluster.", Label("hosted cluster"), func() {
	hostedClusterName := fmt.Sprintf("e2e-cluster-%s", rand.String(6))
	BeforeEach(func() {
		By("import a hosted managedCluster")
		_, err := ApplyHostedManagedCluster(hostedClusterName)
		Expect(err).NotTo(HaveOccurred())

		_, err = ApplyHostedClusterResources(hostedClusterName)
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		By("clean up the resources of the cluster")
		Eventually(func() error {
			_, err := HubClients.KubeClient.CoreV1().Namespaces().Get(context.TODO(), hostedClusterNamespace, metav1.GetOptions{})
			if errors.IsNotFound(err) {
				return nil
			}

			err = HubClients.KubeClient.CoreV1().Namespaces().Delete(context.TODO(), hostedClusterNamespace, metav1.DeleteOptions{})
			if errors.IsNotFound(err) {
				return nil
			}
			return fmt.Errorf("wait the ns is deleted. %v", err)
		}).Should(Succeed())

		Eventually(func() error {
			serviceNamespace := hostedClusterNamespace + "-" + hostedClusterName
			_, err := HubClients.KubeClient.CoreV1().Namespaces().Get(context.TODO(), serviceNamespace, metav1.GetOptions{})
			if errors.IsNotFound(err) {
				return nil
			}

			err = HubClients.KubeClient.CoreV1().Namespaces().Delete(context.TODO(), serviceNamespace, metav1.DeleteOptions{})
			if errors.IsNotFound(err) {
				return nil
			}

			return fmt.Errorf("wait ns is deleted. %v", err)
		}).Should(Succeed())

		Eventually(func() error {
			_, err := HubClients.ClusterClient.ClusterV1().ManagedClusters().Get(context.TODO(), hostedClusterName, metav1.GetOptions{})
			if errors.IsNotFound(err) {
				return nil
			}

			return HubClients.ClusterClient.ClusterV1().ManagedClusters().Delete(context.TODO(), hostedClusterName, metav1.DeleteOptions{})
		}).Should(Succeed())
	})

	It("Check the resources of imported hosted managedCluster are created", func() {
		By("external-managed-kubeconfig should be created")
		Eventually(func() error {
			klusteletNs := "klusterlet-" + hostedClusterName
			_, err := HubClients.KubeClient.CoreV1().Secrets(klusteletNs).Get(context.TODO(), "external-managed-kubeconfig", metav1.GetOptions{})
			return err
		}).Should(Succeed())

		By("addons should be created")
		Eventually(func() error {
			addons, err := HubClients.AddonClient.AddonV1alpha1().ManagedClusterAddOns(hostedClusterName).
				List(context.Background(), metav1.ListOptions{})
			if err != nil {
				return fmt.Errorf("failed list addons: %v", err)
			}

			if len(addons.Items) != 3 {
				return fmt.Errorf("expect 3 addons but got %v", len(addons.Items))
			}

			for _, addon := range addons.Items {
				switch addon.GetName() {
				case "work-manager", "config-policy-controller", "governance-policy-framework":
				default:
					return fmt.Errorf("the addon %s is not supported", addon.GetName())
				}
			}

			return nil
		}).Should(Succeed())
	})

})
