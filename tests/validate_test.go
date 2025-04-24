package test

import (
	"testing"
	"os/exec"
	"path/filepath"
	"fmt"
	"strings"
)

func TestTerraformValidate(t *testing.T) {
	providers := []string{"aws", "azure", "gcp", "common-networking"}
	
	for _, provider := range providers {
		t.Run(provider, func(t *testing.T) {
			// Get the absolute path to the module
			moduleDir, err := filepath.Abs(fmt.Sprintf("../%s", provider))
			if err != nil {
				t.Fatalf("Failed to get absolute path: %v", err)
			}
			
			// Run terraform init
			initCmd := exec.Command("terraform", "init", "-backend=false")
			initCmd.Dir = moduleDir
			initOutput, err := initCmd.CombinedOutput()
			if err != nil {
				t.Fatalf("Failed to initialize Terraform in %s: %v\nOutput: %s", 
					provider, err, string(initOutput))
			}
			
			// Run terraform validate
			validateCmd := exec.Command("terraform", "validate")
			validateCmd.Dir = moduleDir
			validateOutput, err := validateCmd.CombinedOutput()
			if err != nil {
				t.Fatalf("Terraform validation failed in %s: %v\nOutput: %s", 
					provider, err, string(validateOutput))
			}
			
			// Check for success message
			if !strings.Contains(string(validateOutput), "Success!") {
				t.Errorf("Unexpected validation output for %s: %s", 
					provider, string(validateOutput))
			} else {
				t.Logf("Module %s validated successfully!", provider)
			}
		})
	}
}
