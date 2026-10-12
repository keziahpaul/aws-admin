#!/bin/bash

# Quick test runner - choose your testing approach
echo "🧪 Empower Data Acquisition - LocalStack Test Runner"
echo ""
echo "Choose your testing approach:"
echo "1. Full Docker Test (recommended, requires Docker)"
echo "2. CLI Test (requires LocalStack CLI)"
echo "3. Syntax Validation (no dependencies)"
echo "4. Manual Configuration Test (no dependencies)"
echo "5. All Non-Docker Tests (3 + 4)"
echo ""

read -p "Enter choice (1-5): " choice

case $choice in
    1)
        echo "🐳 Running Full Docker Test..."
        cd test/localstack && ./test.sh
        ;;
    2)
        echo "💻 Running CLI Test..."
        cd test/localstack && ./simple-test.sh
        ;;
    3)
        echo "📝 Running Syntax Validation..."
        ./test/validate-syntax.sh
        ;;
    4)
        echo "🔍 Running Manual Configuration Test..."
        ./test/manual-config-test.sh
        ;;
    5)
        echo "🚀 Running All Non-Docker Tests..."
        echo ""
        echo "=== Syntax Validation ==="
        ./test/validate-syntax.sh
        echo ""
        echo "=== Manual Configuration Test ==="
        ./test/manual-config-test.sh
        ;;
    *)
        echo "❌ Invalid choice. Please run again with 1-5."
        exit 1
        ;;
esac

echo ""
echo "✅ Testing completed!"
