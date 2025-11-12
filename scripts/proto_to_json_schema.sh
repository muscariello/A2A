#!/bin/bash
set -euo pipefail
# Convert proto files to JSON Schema in a single operation.
# Usage: proto_to_json_schema.sh <output_json_schema>

OUTPUT=${1:-}
if [[ -z "$OUTPUT" ]]; then
  echo "Usage: $0 <output.json>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTO_DIR="$ROOT_DIR/specification/grpc"
PROTO_FILE="$PROTO_DIR/a2a.proto"
GOOGLEAPIS_DIR="${GOOGLEAPIS_DIR:-}"

# Check dependencies
if ! command -v protoc >/dev/null 2>&1; then
  echo "Error: protoc not found on PATH" >&2
  exit 1
fi
if ! command -v protoc-gen-openapi >/dev/null 2>&1; then
  echo "Error: protoc-gen-openapi not found on PATH" >&2
  exit 1
fi
if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq not found on PATH" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found on PATH" >&2
  exit 1
fi

# Create temporary directory for intermediate files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Setup include paths for googleapis
INCLUDE_FLAGS=("-I" "$PROTO_DIR")
if [ -n "$GOOGLEAPIS_DIR" ]; then
  INCLUDE_FLAGS+=("-I" "$GOOGLEAPIS_DIR")
elif [ -d "$ROOT_DIR/third_party/googleapis" ]; then
  INCLUDE_FLAGS+=("-I" "$ROOT_DIR/third_party/googleapis")
elif [ -d "/usr/local/include/google/api" ]; then
  INCLUDE_FLAGS+=("-I" "/usr/local/include")
fi

# Verify googleapis annotations are available
ANNOTATIONS_FOUND=false
for inc in "${INCLUDE_FLAGS[@]}"; do
  dir="${inc#-I}"
  if [ -f "$dir/google/api/annotations.proto" ]; then
    ANNOTATIONS_FOUND=true
    break
  fi
done
if [ "$ANNOTATIONS_FOUND" != true ]; then
  echo "Error: google/api/annotations.proto not found in include paths" >&2
  echo "Set GOOGLEAPIS_DIR env var or ensure third_party/googleapis exists" >&2
  exit 1
fi

# Step 1: Generate OpenAPI v3 YAML from proto
echo "→ Generating OpenAPI v3 from proto..." >&2
if ! protoc "${INCLUDE_FLAGS[@]}" --openapi_out "$TEMP_DIR" \
    --openapi_opt naming=json \
    "$PROTO_FILE"; then
  echo "Error: protoc generation failed" >&2
  exit 1
fi

OPENAPI_YAML="$TEMP_DIR/openapi.yaml"
if [[ ! -f "$OPENAPI_YAML" ]]; then
  echo "Error: No openapi.yaml produced" >&2
  exit 1
fi

# Step 2: Convert YAML to JSON
echo "→ Converting YAML to JSON..." >&2
OPENAPI_JSON="$TEMP_DIR/openapi.json"
yq -o=json '.' "$OPENAPI_YAML" > "$OPENAPI_JSON"

# Step 3: Extract schemas and wrap in JSON Schema structure
echo "→ Extracting schemas..." >&2
SCHEMA_DEFS=$(jq 'if .components and .components.schemas then .components.schemas elif .definitions then .definitions else {} end' "$OPENAPI_JSON")

if [[ -z "$SCHEMA_DEFS" || "$SCHEMA_DEFS" == "null" || "$SCHEMA_DEFS" == "{}" ]]; then
  echo "Warning: No schemas found in OpenAPI document" >&2
  SCHEMA_DEFS="{}"
fi

# Step 4: Create final JSON Schema bundle
echo "→ Creating JSON Schema bundle..." >&2
jq -n --argjson defs "$SCHEMA_DEFS" '{
  "$schema": "http://json-schema.org/draft-07/schema#",
  title: "A2A Protocol Schemas",
  description: "Non-normative JSON Schema bundle extracted from proto definitions via OpenAPI.",
  version: "v1",
  definitions: $defs
}' > "$OUTPUT"

# Count definitions
DEF_COUNT=$(jq '.definitions | length' "$OUTPUT")
echo "✓ Generated $OUTPUT with $DEF_COUNT definitions" >&2
