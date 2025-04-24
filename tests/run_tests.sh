#!/bin/bash

echo "Running syntax validation tests..."
go test -v -run TestTerraformValidate

echo "Done! All tests completed."
