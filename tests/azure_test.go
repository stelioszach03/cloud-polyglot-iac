package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func TestAzureInfrastructure(t *testing.T) {
	t.Parallel()

	// Make a copy of the terraform directory to a temporary directory
	workingDir := test_structure.CopyTerraformFolderToTemp(t, "..", "azure")

	// Generate a random project name to prevent a naming conflict
	uniqueID := random.UniqueId()
	projectName := fmt.Sprintf("terratest-%s", uniqueID)

	// Configure Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: workingDir,
		Vars: map[string]interface{}{
			"location":     "eastus",
			"project_name": projectName,
			"environment":  "test",
			// Use smaller VM sizes and counts for testing to reduce costs
			"vm_size":            "Standard_B2s",
			"node_count":         1,
			"min_count":          1,
			"max_count":          1,
			"enable_auto_scaling": true,
		},
		// Retry on known errors
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
		NoColor:            true,
	}

	// Clean up resources when the test is complete
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply the Terraform code
	terraform.InitAndApply(t, terraformOptions)

	// Test resource group
	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	assert.NotEmpty(t, resourceGroupName, "Resource group name should not be empty")

	// Test virtual network
	vnetName := terraform.Output(t, terraformOptions, "virtual_network_name")
	assert.NotEmpty(t, vnetName, "Virtual network name should not be empty")

	vnetID := terraform.Output(t, terraformOptions, "virtual_network_id")
	assert.NotEmpty(t, vnetID, "Virtual network ID should not be empty")

	// Test subnets
	publicSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.NotEmpty(t, publicSubnetIDs, "Public subnet IDs should not be empty")
	assert.Equal(t, 3, len(publicSubnetIDs), "There should be 3 public subnets")

	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.NotEmpty(t, privateSubnetIDs, "Private subnet IDs should not be empty")
	assert.Equal(t, 3, len(privateSubnetIDs), "There should be 3 private subnets")

	// Test AKS cluster
	aksClusterName := terraform.Output(t, terraformOptions, "aks_cluster_name")
	assert.NotEmpty(t, aksClusterName, "AKS cluster name should not be empty")

	aksClusterID := terraform.Output(t, terraformOptions, "aks_cluster_id")
	assert.NotEmpty(t, aksClusterID, "AKS cluster ID should not be empty")

	// Test Kubernetes version
	kubernetesVersion := terraform.Output(t, terraformOptions, "kubernetes_version")
	assert.NotEmpty(t, kubernetesVersion, "Kubernetes version should not be empty")
}
