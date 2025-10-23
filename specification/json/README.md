# A2A JSON Artifact

`a2a.json` is a **non-normative build artifact** derived from the canonical proto definition at `specification/grpc/a2a.proto`. It is generated during builds and intentionally **not** committed to source control.

Generation pipeline:

1. `protoc` + `protoc-gen-openapiv2` produce `specification/grpc/openapi/a2a.swagger.json`.
2. `scripts/extract_json_schema.sh` extracts `definitions` into `specification/json/a2a.json` (draft-07 schema bundle).

The artifact is generated automatically in:

- Local docs builds (`scripts/build_docs.sh`)
- CI workflow (`.github/workflows/generate-a2a-json.yml`) on proto changes

## Do Not Edit

Do **NOT** edit `a2a.json` manually. Update the proto instead. The file is transient.

## Future Work

Planned improvements include optional OpenAPI v3 conversion and publishing a draft 2020-12 `components.schemas` bundle.
