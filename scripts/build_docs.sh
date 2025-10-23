#!/bin/bash
set -euo pipefail

# Unified docs build script that ensures the non-normative JSON artifact is
# regenerated (if stale) before invoking MkDocs. Uses pure shell + npm.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCHEMA_JSON="$ROOT_DIR/specification/json/a2a.json"
SCHEMA_JSON_SITE_DIR="$ROOT_DIR/docs/spec-json"
SCHEMA_JSON_SITE_FILE="$SCHEMA_JSON_SITE_DIR/a2a.json"
PROTO_SRC="$ROOT_DIR/specification/grpc/a2a.proto"
TS_SRC="$ROOT_DIR/types/src/types.ts"
OPENAPI_DIR="$ROOT_DIR/specification/grpc/openapi"
OPENAPI_FILE_V2="$OPENAPI_DIR/a2a.swagger.json"
EXTRACT_SCRIPT="$ROOT_DIR/scripts/extract_json_schema.sh"

regen_needed() {
  if [ ! -f "$SCHEMA_JSON" ]; then return 0; fi
  local newest_source
  newest_source=$(stat -f %m "$PROTO_SRC" "$TS_SRC" | sort -nr | head -n1)
  local schema_time
  schema_time=$(stat -f %m "$SCHEMA_JSON")
  [ "$newest_source" -gt "$schema_time" ]
}

echo "[build_docs] Checking schema freshness..." >&2
echo "[build_docs] Regenerating a2a.json from proto (OpenAPI -> definitions)" >&2
if [ -x "$ROOT_DIR/scripts/generate_openapi.sh" ]; then
  bash "$ROOT_DIR/scripts/generate_openapi.sh" || echo "[build_docs] Warning: OpenAPI generation failed" >&2
  if [ -f "$OPENAPI_FILE_V2" ]; then
    if [ -x "$EXTRACT_SCRIPT" ]; then
      bash "$EXTRACT_SCRIPT" "$OPENAPI_FILE_V2" "$SCHEMA_JSON" || echo "[build_docs] Warning: schema extraction failed" >&2
      # Copy into docs/ tree so MkDocs can publish the ephemeral artifact.
      if [ -f "$SCHEMA_JSON" ]; then
        mkdir -p "$SCHEMA_JSON_SITE_DIR"
        cp "$SCHEMA_JSON" "$SCHEMA_JSON_SITE_FILE"
        echo "[build_docs] Published schema to $SCHEMA_JSON_SITE_FILE" >&2
      else
        echo "[build_docs] Schema file missing after extraction: $SCHEMA_JSON" >&2
      fi
    else
      echo "[build_docs] Extraction script not executable: $EXTRACT_SCRIPT" >&2
    fi
  else
    echo "[build_docs] OpenAPI file not found at $OPENAPI_FILE_V2" >&2
  fi
else
  echo "[build_docs] generate_openapi.sh missing or not executable; skipping proto-derived schema generation." >&2
fi



echo "[build_docs] Building MkDocs site..." >&2
mkdocs build "$@"
echo "[build_docs] Done." >&2
