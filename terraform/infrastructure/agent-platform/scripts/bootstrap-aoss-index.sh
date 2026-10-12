#!/usr/bin/env bash
# Bootstrap script: Creates the OpenSearch Serverless index required by Bedrock KB.
# Run ONCE before the main terraform apply.
#
# Usage:
#   ./scripts/bootstrap-aoss-index.sh <collection-name> <index-name> <kb-role-arn>
#
# Example:
#   ./scripts/bootstrap-aoss-index.sh onedata-dev-agent-platform dev-pia-index arn:aws:iam::042775015153:role/dev-pia-agent-bedrock-kb

set -euo pipefail

COLLECTION_NAME="${1:?Usage: $0 <collection-name> <index-name> <kb-role-arn>}"
INDEX_NAME="${2:?Usage: $0 <collection-name> <index-name> <kb-role-arn>}"
KB_ROLE_ARN="${3:?Usage: $0 <collection-name> <index-name> <kb-role-arn>}"
REGION="${AWS_REGION:-ap-southeast-2}"
DIMENSION="${4:-1024}"  # Titan Embed V2 = 1024 dimensions

echo "=== AOSS Index Bootstrap ==="
echo "Collection: $COLLECTION_NAME"
echo "Index:      $INDEX_NAME"
echo "KB Role:    $KB_ROLE_ARN"
echo "Region:     $REGION"
echo "Dimension:  $DIMENSION"
echo ""

# 1. Get collection endpoint
echo "→ Getting collection endpoint..."
ENDPOINT=$(aws opensearchserverless batch-get-collection \
  --names "$COLLECTION_NAME" \
  --region "$REGION" \
  --query 'collectionDetails[0].collectionEndpoint' \
  --output text)

if [[ "$ENDPOINT" == "None" || -z "$ENDPOINT" ]]; then
  echo "❌ Collection '$COLLECTION_NAME' not found or not ACTIVE"
  exit 1
fi
echo "  Endpoint: $ENDPOINT"

# 2. Check if index already exists
echo "→ Checking if index exists..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$ENDPOINT/$INDEX_NAME" \
  --aws-sigv4 "aws:amz:$REGION:aoss" \
  --user "" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "✅ Index '$INDEX_NAME' already exists. Nothing to do."
  exit 0
elif [[ "$HTTP_CODE" == "403" ]]; then
  echo "⚠️  Got 403 - current role may not have AOSS data access."
  echo "   The index must be created by the KB role ($KB_ROLE_ARN)."
  echo ""
  echo "   Options:"
  echo "   1. Assume the KB role and re-run this script"
  echo "   2. Create the index manually via the AWS Console:"
  echo "      - Go to OpenSearch Serverless > Collections > $COLLECTION_NAME"
  echo "      - Create index '$INDEX_NAME' with the mapping below"
  echo ""
  echo "   Index mapping (copy-paste into console):"
  cat <<MAPPING
{
  "settings": {
    "index": {
      "number_of_shards": 2,
      "number_of_replicas": 0,
      "knn": true,
      "knn.algo_param.ef_search": 512
    }
  },
  "mappings": {
    "properties": {
      "embedding": {
        "type": "knn_vector",
        "dimension": $DIMENSION,
        "method": {
          "engine": "faiss",
          "name": "hnsw",
          "parameters": {}
        }
      },
      "text": {
        "type": "text",
        "index": true
      },
      "metadata": {
        "type": "text",
        "index": false
      }
    }
  }
}
MAPPING
  exit 1
fi

# 3. Create the index
echo "→ Creating index '$INDEX_NAME'..."
RESPONSE=$(curl -s -X PUT "$ENDPOINT/$INDEX_NAME" \
  -H "Content-Type: application/json" \
  --aws-sigv4 "aws:amz:$REGION:aoss" \
  --user "" \
  -d "{
    \"settings\": {
      \"index\": {
        \"number_of_shards\": 2,
        \"number_of_replicas\": 0,
        \"knn\": true,
        \"knn.algo_param.ef_search\": 512
      }
    },
    \"mappings\": {
      \"properties\": {
        \"embedding\": {
          \"type\": \"knn_vector\",
          \"dimension\": $DIMENSION,
          \"method\": {
            \"engine\": \"faiss\",
            \"name\": \"hnsw\",
            \"parameters\": {}
          }
        },
        \"text\": {
          \"type\": \"text\",
          \"index\": true
        },
        \"metadata\": {
          \"type\": \"text\",
          \"index\": false
        }
      }
    }
  }" 2>&1)

echo "  Response: $RESPONSE"

if echo "$RESPONSE" | grep -q "acknowledged.*true"; then
  echo "✅ Index '$INDEX_NAME' created successfully."
else
  echo "❌ Failed to create index. Response above."
  exit 1
fi
