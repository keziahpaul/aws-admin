#!/usr/bin/env bash
# validate-all.sh
# Run terraform validate (via terragrunt) on every agent-platform environment.
# Usage: ./scripts/validate-all.sh [--root <repo-root>]
# Requires: terraform, terragrunt (available on PATH)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM_ROOT="$REPO_ROOT/terraform/infrastructure/agent-platform"
ENVS_ROOT="$PLATFORM_ROOT/environments"

PASS=0
FAIL=0
ERRORS=()

print_header() {
  echo ""
  echo "=========================================="
  echo "  Agent Platform - Terraform Validate"
  echo "  Root: $PLATFORM_ROOT"
  echo "=========================================="
  echo ""
}

validate_env() {
  local env_path="$1"
  local label
  label=$(echo "$env_path" | sed "s|$ENVS_ROOT/||")

  echo "  -> $label"

  if [[ ! -f "$env_path/terragrunt.hcl" ]]; then
    echo "     ⚠️  SKIP (no terragrunt.hcl)"
    return
  fi

  # terragrunt validate needs a valid init first; use --terragrunt-source-update
  # so it does not need network access for modules (they are local).
  if terragrunt validate \
      --terragrunt-working-dir "$env_path" \
      --terragrunt-no-auto-init \
      2>&1 | tee /tmp/tg_validate_out.txt; then
    echo "     ✅ PASS"
    PASS=$((PASS + 1))
  else
    echo "     ❌ FAIL"
    ERRORS+=("$label: $(tail -5 /tmp/tg_validate_out.txt)")
    FAIL=$((FAIL + 1))
  fi
}

validate_module_syntax() {
  local mod_path="$1"
  local label
  label=$(echo "$mod_path" | sed "s|$PLATFORM_ROOT/||")

  echo "  -> $label"

  if terraform fmt -check -recursive "$mod_path" 2>&1; then
    echo "     ✅ fmt OK"
  else
    echo "     ⚠️  fmt issues (run: terraform fmt -recursive $label)"
  fi
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
print_header

echo "--- Module HCL format check ---"
for mod in "$PLATFORM_ROOT"/modules/*/; do
  validate_module_syntax "$mod"
done
echo ""

echo "--- Root module HCL format check ---"
validate_module_syntax "$PLATFORM_ROOT"
echo ""

echo "--- Environment validate ---"
for account_dir in "$ENVS_ROOT"/*/; do
  for env_dir in "$account_dir"*/; do
    validate_env "$env_dir"
  done
done
echo ""

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo ""
  echo "Failures:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  exit 1
fi

echo ""
echo "All validations passed ✅"
