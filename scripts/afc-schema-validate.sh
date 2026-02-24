#!/bin/bash
set -euo pipefail

# afc-schema-validate.sh — Validate JSON files against JSON Schema definitions
# Usage: afc-schema-validate.sh [--json-file FILE --schema FILE | --all]
# Exit: 0 = valid, 1 = validation error

# shellcheck disable=SC2329
cleanup() { :; }
trap cleanup EXIT

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SCHEMAS_DIR="${PLUGIN_ROOT}/schemas"

# --- Node.js embedded validator ---
validate_with_node() {
  local json_file="$1" schema_file="$2"
  # shellcheck disable=SC2016
  node -e '
const fs = require("fs");
const jsonFile = process.argv[1];
const schemaFile = process.argv[2];

let data, schema;
try { data = JSON.parse(fs.readFileSync(jsonFile, "utf8")); }
catch (e) { console.error("[afc:schema] JSON parse error in " + jsonFile + ": " + e.message); process.exit(1); }
try { schema = JSON.parse(fs.readFileSync(schemaFile, "utf8")); }
catch (e) { console.error("[afc:schema] Schema parse error in " + schemaFile + ": " + e.message); process.exit(1); }

const errors = [];

function validate(value, sch, path) {
  if (!sch || typeof sch !== "object") return;

  // type check
  if (sch.type) {
    const t = sch.type;
    const actual = Array.isArray(value) ? "array" : typeof value;
    if (actual === "number" && t === "integer") {
      if (!Number.isInteger(value)) errors.push(path + ": expected integer, got float");
    } else if (t !== actual) {
      errors.push(path + ": expected " + t + ", got " + actual);
      return;
    }
  }

  // enum check
  if (sch.enum && !sch.enum.includes(value)) {
    errors.push(path + ": value \"" + value + "\" not in enum [" + sch.enum.join(", ") + "]");
  }

  // pattern check
  if (sch.pattern && typeof value === "string") {
    if (!new RegExp(sch.pattern).test(value)) {
      errors.push(path + ": \"" + value + "\" does not match pattern " + sch.pattern);
    }
  }

  // minLength
  if (sch.minLength !== undefined && typeof value === "string" && value.length < sch.minLength) {
    errors.push(path + ": string length " + value.length + " < minLength " + sch.minLength);
  }

  // minimum (integer/number)
  if (sch.minimum !== undefined && typeof value === "number" && value < sch.minimum) {
    errors.push(path + ": value " + value + " < minimum " + sch.minimum);
  }

  // minItems (array)
  if (sch.minItems !== undefined && Array.isArray(value) && value.length < sch.minItems) {
    errors.push(path + ": array length " + value.length + " < minItems " + sch.minItems);
  }

  // object validations
  if (typeof value === "object" && value !== null && !Array.isArray(value)) {
    // required
    if (sch.required) {
      for (const r of sch.required) {
        if (!(r in value)) errors.push(path + "." + r + ": required field missing");
      }
    }

    // properties
    if (sch.properties) {
      for (const [k, v] of Object.entries(value)) {
        if (sch.properties[k]) {
          validate(v, sch.properties[k], path + "." + k);
        } else if (sch.patternProperties) {
          let matched = false;
          for (const [pat, patSch] of Object.entries(sch.patternProperties)) {
            if (new RegExp(pat).test(k)) { validate(v, patSch, path + "." + k); matched = true; break; }
          }
          if (!matched && sch.additionalProperties === false) {
            errors.push(path + "." + k + ": unexpected property");
          }
        } else if (sch.additionalProperties === false) {
          errors.push(path + "." + k + ": unexpected property");
        }
      }
    } else if (sch.patternProperties) {
      for (const [k, v] of Object.entries(value)) {
        let matched = false;
        for (const [pat, patSch] of Object.entries(sch.patternProperties)) {
          if (new RegExp(pat).test(k)) { validate(v, patSch, path + "." + k); matched = true; break; }
        }
        if (!matched && sch.additionalProperties === false) {
          errors.push(path + "." + k + ": unexpected property");
        }
      }
    }
  }

  // array validations
  if (Array.isArray(value) && sch.items) {
    for (let i = 0; i < value.length; i++) {
      validate(value[i], sch.items, path + "[" + i + "]");
    }
  }

  // $ref resolution (local definitions only)
  if (sch["$ref"]) {
    const refPath = sch["$ref"].replace("#/definitions/", "");
    if (schema.definitions && schema.definitions[refPath]) {
      validate(value, schema.definitions[refPath], path);
    }
  }
}

validate(data, schema, "$");

if (errors.length > 0) {
  console.error("[afc:schema] " + jsonFile + " validation failed:");
  errors.forEach(e => console.error("  " + e));
  process.exit(1);
} else {
  console.log("[afc:schema] " + jsonFile + " — valid");
}
' "$json_file" "$schema_file"
}

# --- jq fallback (basic structure only) ---
validate_with_jq() {
  local json_file="$1" schema_file="$2"

  # Step 1: valid JSON?
  if ! jq empty "$json_file" 2>/dev/null; then
    printf '%s\n' "[afc:schema] JSON parse error in ${json_file}" >&2
    return 1
  fi

  # Step 2: check required top-level keys from schema
  local required_keys
  required_keys=$(jq -r '.required[]? // empty' "$schema_file" 2>/dev/null || true)
  if [ -n "$required_keys" ]; then
    local missing=0
    while IFS= read -r key; do
      if ! jq -e ".[\"${key}\"]" "$json_file" >/dev/null 2>&1; then
        printf '%s\n' "[afc:schema] ${json_file}: required field missing: ${key}" >&2
        missing=1
      fi
    done <<< "$required_keys"
    if [ "$missing" -eq 1 ]; then
      return 1
    fi
  fi

  printf '%s\n' "[afc:schema] ${json_file} — valid (jq basic)"
  return 0
}

# --- Main ---
validate_file() {
  local json_file="$1" schema_file="$2"

  if [ ! -f "$json_file" ]; then
    printf '%s\n' "[afc:schema] File not found: ${json_file}" >&2
    return 1
  fi
  if [ ! -f "$schema_file" ]; then
    printf '%s\n' "[afc:schema] Schema not found: ${schema_file}" >&2
    return 1
  fi

  if command -v node >/dev/null 2>&1; then
    validate_with_node "$json_file" "$schema_file"
  elif command -v jq >/dev/null 2>&1; then
    printf '%s\n' "[afc:schema] WARNING: node not found, using jq basic validation" >&2
    validate_with_jq "$json_file" "$schema_file"
  else
    printf '%s\n' "[afc:schema] WARNING: neither node nor jq found, skipping validation" >&2
    return 0
  fi
}

# Parse arguments
MODE="all"
JSON_FILE=""
SCHEMA_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json-file) JSON_FILE="$2"; MODE="single"; shift 2 ;;
    --schema) SCHEMA_FILE="$2"; shift 2 ;;
    --all) MODE="all"; shift ;;
    *) printf '%s\n' "[afc] Usage: afc-schema-validate.sh [--json-file FILE --schema FILE | --all]" >&2; exit 1 ;;
  esac
done

if [ "$MODE" = "single" ]; then
  if [ -z "$JSON_FILE" ] || [ -z "$SCHEMA_FILE" ]; then
    printf '%s\n' "[afc] Usage: afc-schema-validate.sh --json-file FILE --schema FILE" >&2
    exit 1
  fi
  validate_file "$JSON_FILE" "$SCHEMA_FILE"
else
  ERRORS=0
  validate_file "${PLUGIN_ROOT}/hooks/hooks.json" "${SCHEMAS_DIR}/hooks.schema.json" || ERRORS=$((ERRORS + 1))
  validate_file "${PLUGIN_ROOT}/.claude-plugin/plugin.json" "${SCHEMAS_DIR}/plugin.schema.json" || ERRORS=$((ERRORS + 1))
  validate_file "${PLUGIN_ROOT}/.claude-plugin/marketplace.json" "${SCHEMAS_DIR}/marketplace.schema.json" || ERRORS=$((ERRORS + 1))
  if [ "$ERRORS" -gt 0 ]; then
    printf '%s\n' "[afc:schema] ${ERRORS} file(s) failed validation" >&2
    exit 1
  fi
  printf '%s\n' "[afc:schema] All 3 files valid"
fi
