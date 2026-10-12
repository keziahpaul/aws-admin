#!/bin/bash

set -e

echo "🔍 Validating Empower Infrastructure Terraform Configurations"

# Function to validate Terraform configuration
validate_terraform() {
    local dir=$1
    local name=$2
    
    echo "📋 Validating $name configuration in $dir..."
    
    if [ ! -d "$dir" ]; then
        echo "❌ Directory $dir does not exist"
        return 1
    fi
    
    cd "$dir"
    
    # Check for required files
    if [ ! -f "main.tf" ]; then
        echo "❌ main.tf not found in $dir"
        return 1
    fi
    
    if [ ! -f "variables.tf" ]; then
        echo "❌ variables.tf not found in $dir"
        return 1
    fi
    
    # Initialize Terraform (this will validate syntax)
    echo "🔧 Initializing Terraform..."
    if terraform init -backend=false > /dev/null 2>&1; then
        echo "✅ Terraform initialization successful"
    else
        echo "❌ Terraform initialization failed"
        return 1
    fi
    
    # Validate configuration
    echo "🔍 Validating Terraform configuration..."
    if terraform validate > /dev/null 2>&1; then
        echo "✅ Terraform validation successful"
    else
        echo "❌ Terraform validation failed"
        terraform validate
        return 1
    fi
    
    # Format check
    echo "📝 Checking Terraform formatting..."
    if terraform fmt -check > /dev/null 2>&1; then
        echo "✅ Terraform formatting is correct"
    else
        echo "⚠️  Terraform formatting needs adjustment"
        terraform fmt -diff
    fi
    
    cd - > /dev/null
    echo "✅ $name validation completed"
    echo ""
}

# Function to validate Terragrunt configuration
validate_terragrunt() {
    local file=$1
    local name=$2
    
    echo "📋 Validating $name Terragrunt configuration..."
    
    if [ ! -f "$file" ]; then
        echo "❌ File $file does not exist"
        return 1
    fi
    
    # Check for required blocks
    if grep -q "include \"root\"" "$file" && \
       grep -q "terraform {" "$file" && \
       grep -q "remote_state {" "$file" && \
       grep -q "inputs = {" "$file"; then
        echo "✅ $name Terragrunt configuration structure is valid"
    else
        echo "❌ $name Terragrunt configuration is missing required blocks"
        return 1
    fi
    
    # Check for required inputs
    if grep -q "environment" "$file" && \
       grep -q "project" "$file" && \
       grep -q "cost_centre" "$file"; then
        echo "✅ $name Terragrunt has required inputs"
    else
        echo "❌ $name Terragrunt is missing required inputs"
        return 1
    fi
    
    echo "✅ $name Terragrunt validation completed"
    echo ""
}

# Start validation
echo "🚀 Starting infrastructure validation..."
echo ""

# Validate S3 infrastructure
validate_terraform "terraform/infrastructure/s3" "S3 Infrastructure"

# Validate Lambda infrastructure
validate_terraform "terraform/infrastructure/lambda" "Lambda Infrastructure"

# Validate Terragrunt configurations
echo "📋 Validating Terragrunt configurations..."
echo ""

# S3 Terragrunt configs
validate_terragrunt "terraform/infrastructure/s3/environments/datanp/dev/terragrunt.hcl" "S3 DataNP Dev"
validate_terragrunt "terraform/infrastructure/s3/environments/datanp/tst/terragrunt.hcl" "S3 DataNP Tst"
validate_terragrunt "terraform/infrastructure/s3/environments/dataprd/pst/terragrunt.hcl" "S3 DataPrd Pst"
validate_terragrunt "terraform/infrastructure/s3/environments/dataprd/prd/terragrunt.hcl" "S3 DataPrd Prd"

# Check if Lambda Terragrunt configs exist (they should be created next)
if [ -f "terraform/infrastructure/lambda/environments/datanp/dev/terragrunt.hcl" ]; then
    validate_terragrunt "terraform/infrastructure/lambda/environments/datanp/dev/terragrunt.hcl" "Lambda DataNP Dev"
else
    echo "⏳ Lambda Terragrunt configurations not yet created (expected)"
fi

echo "🎉 Infrastructure validation completed!"
echo ""
echo "📊 Summary:"
echo "✅ S3 Infrastructure: Terraform configuration valid"
echo "✅ Lambda Infrastructure: Terraform configuration valid"
echo "✅ S3 Terragrunt: All 4 environment configurations valid"
echo "⏳ Lambda Terragrunt: Pending creation"
echo ""
echo "🔧 Next steps:"
echo "1. Complete Lambda Terragrunt configurations"
echo "2. Implement Lambda function code"
echo "3. Create GitHub workflows"
echo "4. Test with actual AWS deployment"
