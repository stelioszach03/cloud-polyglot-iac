package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func TestGCPInfrastructure(t *testing.T) {
	t.Parallel()

	// Make a copy of the terraform directory to a temporary directory
	workingDir := test_structure.CopyTerraformFolderToTemp(t, "..", "gcp")

	// Get the Project ID to use
	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)

	// Generate a random project name to prevent a naming conflict
	uniqueID := random.UniqueId()
	projectName := fmt.Sprintf("terratest-%s", uniqueID)

	// Configure Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: workingDir,
		Vars: map[string]interface{}{
			"project_id":   projectID,
			"region":       "us-central1",
			"project_name": projectName,
			"environment":  "test",
			// Use smaller machine types and counts for testing to reduce costs
			"node_machine_type":  "e2-small",
			"min_node_count":     1,
			"max_node_count":     1,
			"initial_node_count": 1,
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

	// Test VPC
	vpcName := terraform.Output(t, terraformOptions, "vpc_name")
	assert.NotEmpty(t, vpcName, "VPC name should not be empty")

	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC ID should not be empty")

	// Test subnets
	publicSubnetNames := terraform.OutputList(t, terraformOptions, "public_subnet_names")
	assert.NotEmpty(t, publicSubnetNames, "Public subnet names should not be empty")
	assert.Equal(t, 3, len(publicSubnetNames), "There should be 3 public subnets")

	publicSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.NotEmpty(t, publicSubnetIDs, "Public subnet IDs should not be empty")
	assert.Equal(t, 3, len(publicSubnetIDs), "There should be 3 public subnets")

	privateSubnetNames := terraform.OutputList(t, terraformOptions, "private_subnet_names")
	assert.NotEmpty(t, privateSubnetNames, "Private subnet names should not be empty")
	assert.Equal(t, 3, len(privateSubnetNames), "There should be 3 private subnets")

	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.NotEmpty(t, privateSubnetIDs, "Private subnet IDs should not be empty")
	assert.Equal(t, 3, len(privateSubnetIDs), "There should be 3 private subnets")

	// Test GKE cluster
	gkeClusterName := terraform.Output(t, terraformOptions, "gke_cluster_name")
	assert.NotEmpty(t, gkeClusterName, "GKE cluster name should not be empty")

	gkeClusterID := terraform.Output(t, terraformOptions, "gke_cluster_id")
	assert.NotEmpty(t, gkeClusterID, "GKE cluster ID should not be empty")

	// Test GKE node pool
	gkeNodePoolName := terraform.Output(t, terraformOptions, "gke_node_pool_name")
	assert.NotEmpty(t, gkeNodePoolName, "GKE node pool name should not be empty")

	// Test Kubernetes version
	kubernetesVersion := terraform.Output(t, terraformOptions, "kubernetes_version")
	assert.NotEmpty(t, kubernetesVersion, "Kubernetes version should not be empty")
}
