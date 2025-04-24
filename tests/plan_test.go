package test

import (
        "fmt"
        "testing"

        "github.com/gruntwork-io/terratest/modules/random"
        "github.com/gruntwork-io/terratest/modules/terraform"
        test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestAWSPlanOnly(t *testing.T) {
        t.Parallel()

        // Make a copy of the terraform directory to a temporary directory
        workingDir := test_structure.CopyTerraformFolderToTemp(t, "..", "aws")

        // Generate a random project name to prevent a naming conflict
        uniqueID := random.UniqueId()
        projectName := fmt.Sprintf("terratest-%s", uniqueID)

        // Configure Terraform options
        terraformOptions := &terraform.Options{
                TerraformDir: workingDir,
                Vars: map[string]interface{}{
                        "region":       "us-east-1",
                        "project_name": projectName,
                        "environment":  "test",
                        "instance_types": []string{"t3.small"},
                        "min_size":     1,
                        "max_size":     1,
                        "desired_size": 1,
                },
                NoColor: true,
        }

        // Run terraform init and terraform plan
        // This won't create any actual resources
        terraform.InitAndPlan(t, terraformOptions)

        // The test passes if terraform plan runs successfully
        fmt.Println("Terraform plan completed successfully!")
}
