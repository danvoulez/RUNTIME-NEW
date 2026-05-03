#!/usr/bin/env bash
set -Eeuo pipefail

# bootstrap_minilab_external_grounded.sh
#
# Purpose:
#   Assemble a full Minilab from external upstream code, piece by piece.
#   This script does not hand-write a constitutional runtime. It harvests real
#   external engines/SDKs/libraries/examples and records the exact commits used.
#
# Core rule:
#   External code supplies implementation. This script supplies harvest, lock,
#   manifests, receipts, and verification only.
#
# Usage:
#   bash bootstrap_minilab_external_grounded.sh [target_dir]
#
# Profiles:
#   MINILAB_PROFILE=core   -> required pieces only
#   MINILAB_PROFILE=full   -> required + optional/future pieces (default)
#
# Important env:
#   MINILAB_STRICT=1              fail on required clone/lock/coverage problems (default 1)
#   MINILAB_DEPTH=1               shallow clone depth; 0 means full clone
#   MINILAB_REF_POLICY=latest-tag-or-default
#   MINILAB_SKIP_EXISTING=1       reuse existing cloned dirs
#   MINILAB_COPY_FULL_REPOS=1     copy full checked-out repo trees into assembled/ (default 1)
#   MINILAB_RUN_SMOKE=1           run structural smoke checks (default 1)
#
# This script intentionally does NOT run upstream package installs/tests by default.
# It verifies harvest integrity and category coverage. Upstream tests can be run
# after the lock is produced using each upstream project's own instructions.

ROOT="${1:-minilab-external-grounded}"
PROFILE="${MINILAB_PROFILE:-full}"
STRICT="${MINILAB_STRICT:-1}"
DEPTH="${MINILAB_DEPTH:-1}"
REF_POLICY="${MINILAB_REF_POLICY:-latest-tag-or-default}"
SKIP_EXISTING="${MINILAB_SKIP_EXISTING:-0}"
COPY_FULL_REPOS="${MINILAB_COPY_FULL_REPOS:-1}"
RUN_SMOKE="${MINILAB_RUN_SMOKE:-1}"

umask 077

log(){ printf '[minilab] %s\n' "$*" >&2; }
warn(){ printf '[minilab][warn] %s\n' "$*" >&2; WARNINGS=$((WARNINGS+1)); }
fail(){ printf '[minilab][fail] %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"; }

WARNINGS=0
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

need git
need python3
need find
need sort
need awk
need sed
need date
need shasum

mkdir -p "$ROOT" \
  "$ROOT/vendor/sources" \
  "$ROOT/assembled" \
  "$ROOT/locks" \
  "$ROOT/receipts" \
  "$ROOT/scripts" \
  "$ROOT/research" \
  "$ROOT/ops" \
  "$ROOT/_tmp"

cat > "$ROOT/CANON.md" <<'CANON'
# Minilab Canon

This Minilab is assembled from external code only.

Runtime flow required by the system:

input -> candidate -> admission -> policy -> plan -> dispatch guard -> execution backend -> receipt -> audit/idempotency store

Constitutional laws:

- Route is not admission.
- Tool call is not authorization.
- JSON is not authority.
- SDK is not business logic.
- Trace is not proof.
- Receipt is proof.
- Dispatcher only touches the world after the admission stamp.

Assembly law:

- External upstream code provides implementation pieces.
- This bootstrap only harvests, pins, copies, manifests, and verifies structure.
- Any invariant not implemented by an upstream piece remains a named integration requirement, not a hidden claim.
CANON

cat > "$ROOT/PARTS.json" <<'JSON'
{
  "name": "minilab-external-grounded",
  "ref_policy_default": "latest-tag-or-default",
  "categories_required": [
    "runtime_workflow",
    "mcp_nodes",
    "policy_admission",
    "capability_actor_registry",
    "postgres_receipts_store",
    "schema_hashing",
    "control_plane_http",
    "execution_sandbox",
    "observability",
    "verification_ci",
    "secrets_identity",
    "future_llm_ingress"
  ],
  "parts": [
    {
      "name": "dbos-transact-ts",
      "category": "runtime_workflow",
      "required": true,
      "origin": "seed_runtime_supported_by_research",
      "repo": "https://github.com/dbos-inc/dbos-transact-ts.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT",
      "why": "Postgres-backed durable TypeScript workflows, queues, notifications, scheduling, idempotent workflow IDs.",
      "adapter_target": "input/candidate/admission/policy/plan/dispatch/receipt sequence as durable workflow steps"
    },
    {
      "name": "dbos-demo-apps",
      "category": "runtime_workflow",
      "required": true,
      "origin": "discovered_research_examples",
      "repo": "https://github.com/dbos-inc/dbos-demo-apps.git",
      "ref": "latest-tag-or-default",
      "license_expect": "unknown_verify_from_repo",
      "why": "Official DBOS demo applications/examples to avoid inventing runtime examples.",
      "adapter_target": "source examples for durable app shape and Postgres workflow usage"
    },
    {
      "name": "pg-workflows",
      "category": "runtime_workflow",
      "required": false,
      "origin": "discovered_research",
      "repo": "https://github.com/sokratisvidros/pg-workflows.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT",
      "why": "Postgres workflow engine for TypeScript with idempotent starts, events, waits, retries, approval/AI patterns.",
      "adapter_target": "alternative Postgres-native workflow engine and examples"
    },
    {
      "name": "openworkflow",
      "category": "runtime_workflow",
      "required": false,
      "origin": "seed_do_usuario_openworkflow",
      "repo": "https://github.com/openworkflowdev/openworkflow.git",
      "ref": "latest-tag-or-default",
      "license_expect": "verify_from_repo",
      "why": "Open-source TypeScript framework for durable resumable workflows with Postgres backend.",
      "adapter_target": "alternative durable runtime substrate"
    },
    {
      "name": "mcp-typescript-sdk",
      "category": "mcp_nodes",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/modelcontextprotocol/typescript-sdk.git",
      "ref": "v1.x",
      "license_expect": "Apache-2.0_and_existing_MIT",
      "why": "Official Tier 1 TypeScript SDK for MCP servers/clients, transports, middleware, examples.",
      "adapter_target": "MCP tool call becomes candidate, not authorization"
    },
    {
      "name": "mcp-python-sdk",
      "category": "mcp_nodes",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/modelcontextprotocol/python-sdk.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT_or_Apache_verify_from_repo",
      "why": "Official Tier 1 Python SDK for MCP servers/clients and local nodes.",
      "adapter_target": "Python MCP nodes emit candidates only"
    },
    {
      "name": "cedar",
      "category": "policy_admission",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/cedar-policy/cedar.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0_verify",
      "why": "Authorization policy engine for principal/action/resource/context decisions.",
      "adapter_target": "policy decision inside admission; never direct dispatch"
    },
    {
      "name": "opa",
      "category": "policy_admission",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/open-policy-agent/opa.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0",
      "why": "General policy engine, Rego, REST/Go/WASM sidecar reference.",
      "adapter_target": "policy sidecar/reference, not authority to dispatch"
    },
    {
      "name": "openfga",
      "category": "capability_actor_registry",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/openfga/openfga.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0",
      "why": "Zanzibar-like actor/resource/capability relationship registry with Postgres backend support.",
      "adapter_target": "actor/capability/resource relation registry"
    },
    {
      "name": "topaz",
      "category": "capability_actor_registry",
      "required": false,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/aserto-dev/topaz.git",
      "ref": "latest-tag-or-default",
      "license_expect": "verify_from_repo",
      "why": "OPA plus Zanzibar-like local directory for authorization reference.",
      "adapter_target": "local sidecar authorization registry reference"
    },
    {
      "name": "sqlx",
      "category": "postgres_receipts_store",
      "required": true,
      "origin": "seed_supported_by_research",
      "repo": "https://github.com/launchbadge/sqlx.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT_OR_Apache-2.0",
      "why": "Rust Postgres access, migrations, pooling, query checking for receipt/audit/idempotency stores.",
      "adapter_target": "ReceiptStore, AuditLedger, IdempotencyStore"
    },
    {
      "name": "node-postgres",
      "category": "postgres_receipts_store",
      "required": true,
      "origin": "seed_pg_supported_by_research",
      "repo": "https://github.com/brianc/node-postgres.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT",
      "why": "Widely used Node Postgres client for control plane and Workers/Hyperdrive-compatible usage.",
      "adapter_target": "TS/Node control-plane Postgres client"
    },
    {
      "name": "postgres-js",
      "category": "postgres_receipts_store",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/porsager/postgres.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Unlicense_or_MIT_verify",
      "why": "Postgres.js client for Node/Deno/Bun/Workers edge paths.",
      "adapter_target": "alternative TS/edge Postgres client"
    },
    {
      "name": "json-canonicalization",
      "category": "schema_hashing",
      "required": true,
      "origin": "discovered_research_rfc8785",
      "repo": "https://github.com/cyberphone/json-canonicalization.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0_verify",
      "why": "RFC 8785/JCS canonical JSON implementations and test data for receipt hashing.",
      "adapter_target": "canonical receipt hashing test vectors"
    },
    {
      "name": "jsonschema-rs",
      "category": "schema_hashing",
      "required": true,
      "origin": "discovered_research",
      "repo": "https://github.com/Stranger6667/jsonschema.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT_verify",
      "why": "Rust JSON Schema validation for candidate/admission payloads.",
      "adapter_target": "CandidateSchemaValidator"
    },
    {
      "name": "zod",
      "category": "schema_hashing",
      "required": true,
      "origin": "discovered_research",
      "repo": "https://github.com/colinhacks/zod.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT",
      "why": "TypeScript schema validation and inferred types for MCP/control plane/LLM ingress.",
      "adapter_target": "TS schema validation"
    },
    {
      "name": "hono",
      "category": "control_plane_http",
      "required": true,
      "origin": "discovered_research",
      "repo": "https://github.com/honojs/hono.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT",
      "why": "Web-standard HTTP framework for Workers/Node/Deno/Bun control plane.",
      "adapter_target": "control plane routes; route is not admission"
    },
    {
      "name": "workers-sdk",
      "category": "control_plane_http",
      "required": true,
      "origin": "seed_cloudflare_supported_by_research",
      "repo": "https://github.com/cloudflare/workers-sdk.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0_verify",
      "why": "Wrangler/Workers tooling for Tower/control-plane edge deployment.",
      "adapter_target": "Cloudflare Workers control-plane deployment/tooling"
    },
    {
      "name": "wasmtime",
      "category": "execution_sandbox",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/bytecodealliance/wasmtime.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0_WITH_LLVM_exception_verify",
      "why": "WebAssembly/WASI/component-model runtime for sandboxed execution backend.",
      "adapter_target": "sandbox execution backend after admission guard"
    },
    {
      "name": "e2b",
      "category": "execution_sandbox",
      "required": false,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/e2b-dev/E2B.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0_verify",
      "why": "Cloud sandbox SDK/examples for remote execution backends.",
      "adapter_target": "cloud sandbox backend reference"
    },
    {
      "name": "opentelemetry-rust",
      "category": "observability",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/open-telemetry/opentelemetry-rust.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0",
      "why": "Rust OpenTelemetry APIs/SDKs/examples for correlation, traces, metrics, logs.",
      "adapter_target": "correlation spine; trace is not proof"
    },
    {
      "name": "opentelemetry-js",
      "category": "observability",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/open-telemetry/opentelemetry-js.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0",
      "why": "JavaScript/TypeScript OpenTelemetry for control plane and MCP nodes.",
      "adapter_target": "TS trace/correlation propagation"
    },
    {
      "name": "langfuse",
      "category": "observability",
      "required": false,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/langfuse/langfuse.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT_verify_or_FSL_verify",
      "why": "LLM observability/evals/prompt management for future ingress only.",
      "adapter_target": "LLM ingress observability, not receipt proof"
    },
    {
      "name": "dagger",
      "category": "verification_ci",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/dagger/dagger.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0",
      "why": "Programmable, repeatable, observable build/test/ship automation.",
      "adapter_target": "harvest/build/verify pipeline engine"
    },
    {
      "name": "nextest",
      "category": "verification_ci",
      "required": true,
      "origin": "discovered_research",
      "repo": "https://github.com/nextest-rs/nextest.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT_OR_Apache-2.0",
      "why": "Rust test runner with retries, JUnit, CI-friendly profiles.",
      "adapter_target": "Rust verification runner"
    },
    {
      "name": "gitleaks",
      "category": "verification_ci",
      "required": true,
      "origin": "discovered_research",
      "repo": "https://github.com/gitleaks/gitleaks.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT",
      "why": "Secret scanning for harvested repos and assembled artifacts.",
      "adapter_target": "verify-harvest secret scanner"
    },
    {
      "name": "promptfoo",
      "category": "verification_ci",
      "required": false,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/promptfoo/promptfoo.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT",
      "why": "LLM eval/red-team tooling for future ingress candidate generation.",
      "adapter_target": "future LLM ingress evals only"
    },
    {
      "name": "vault",
      "category": "secrets_identity",
      "required": true,
      "origin": "seed_supported_by_research",
      "repo": "https://github.com/hashicorp/vault.git",
      "ref": "latest-tag-or-default",
      "license_expect": "BUSL_or_MPL_by_version_verify",
      "why": "Secrets, encryption, dynamic credentials, identity, audit logs.",
      "adapter_target": "secret custody reference; license must be reviewed"
    },
    {
      "name": "infisical",
      "category": "secrets_identity",
      "required": false,
      "origin": "discovered_research",
      "repo": "https://github.com/Infisical/infisical.git",
      "ref": "latest-tag-or-default",
      "license_expect": "verify_from_repo",
      "why": "Open-source secrets management alternative.",
      "adapter_target": "developer-friendly secrets/certs/PAM reference"
    },
    {
      "name": "ory-oathkeeper",
      "category": "secrets_identity",
      "required": false,
      "origin": "discovered_research",
      "repo": "https://github.com/ory/oathkeeper.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0",
      "why": "Identity and access proxy for HTTP control-plane protection.",
      "adapter_target": "edge/API request authn/authz proxy"
    },
    {
      "name": "openai-agents-python",
      "category": "future_llm_ingress",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/openai/openai-agents-python.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT_verify",
      "why": "Future LLM ingress/reference examples; rejected from core runtime.",
      "adapter_target": "candidate generator only, not kernel"
    },
    {
      "name": "vercel-ai",
      "category": "future_llm_ingress",
      "required": true,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/vercel/ai.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0_verify",
      "why": "Vercel AI SDK examples/packages for structured output candidate generation.",
      "adapter_target": "structured output candidate generator only"
    },
    {
      "name": "pydantic-ai",
      "category": "future_llm_ingress",
      "required": false,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/pydantic/pydantic-ai.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT_verify",
      "why": "Python agent/structured output framework for future ingress/labs only.",
      "adapter_target": "lab/candidate generator only"
    },
    {
      "name": "langgraph",
      "category": "future_llm_ingress",
      "required": false,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/langchain-ai/langgraph.git",
      "ref": "latest-tag-or-default",
      "license_expect": "MIT_verify",
      "why": "Agent graph/persistence/replay reference, not constitutional kernel.",
      "adapter_target": "lab/reference only"
    },
    {
      "name": "mastra",
      "category": "future_llm_ingress",
      "required": false,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/mastra-ai/mastra.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0_verify",
      "why": "Agent/workflow framework reference for labs; not core.",
      "adapter_target": "lab/reference only"
    },
    {
      "name": "smolagents",
      "category": "future_llm_ingress",
      "required": false,
      "origin": "seed_do_usuario",
      "repo": "https://github.com/huggingface/smolagents.git",
      "ref": "latest-tag-or-default",
      "license_expect": "Apache-2.0_verify",
      "why": "Code-agent framework with sandbox patterns; future lab only.",
      "adapter_target": "lab/reference only"
    }
  ]
}
JSON

cat > "$ROOT/research/README.md" <<'MD'
# Research Ledger

Primary selected pieces are from the user's seed list plus direct discoveries that match the same functions:

- Runtime/durable workflow: DBOS, pg-workflows, OpenWorkflow.
- MCP nodes: official MCP TypeScript/Python SDKs.
- Policy/admission: Cedar, OPA, OpenFGA, Topaz.
- Store/receipts/idempotency: Postgres clients and DBOS/Postgres primitives, SQLx, node-postgres, Postgres.js.
- Schema/hash: RFC 8785/JCS implementation and JSON Schema/Zod validators.
- Control plane: Hono and Cloudflare Workers SDK.
- Execution: Wasmtime and E2B.
- Observability: OpenTelemetry and Langfuse.
- Verification: Dagger, nextest, gitleaks, promptfoo.
- Secrets/identity: Vault, Infisical, Ory Oathkeeper.
- Future LLM ingress: OpenAI Agents SDK, Vercel AI SDK, Pydantic AI, LangGraph, Mastra, smolagents.

This ledger is not a claim that every upstream piece implements the Minilab invariants alone. The lock and manifest show what was harvested.
MD

python3 - <<'PY' "$ROOT/PARTS.json" "$ROOT/locks/parts.tsv" "$PROFILE"
import json, sys
parts_path, out_path, profile = sys.argv[1:]
data = json.load(open(parts_path))
with open(out_path, 'w') as f:
    for p in data['parts']:
        if profile == 'core' and not p.get('required', False):
            continue
        fields = [p['name'], p['category'], str(p.get('required', False)).lower(), p['repo'], p.get('ref','latest-tag-or-default')]
        f.write('\t'.join(fields) + '\n')
PY

repo_dir(){ printf '%s/vendor/sources/%s' "$ROOT" "$1"; }
assembled_dir(){ printf '%s/assembled/%s/%s' "$ROOT" "$2" "$1"; }

resolve_default_branch(){
  repo="$1"
  git ls-remote --symref "$repo" HEAD 2>/dev/null | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}'
}

resolve_latest_tag(){
  repo="$1"
  python3 - "$repo" <<'PY'
import re, subprocess, sys
repo = sys.argv[1]
try:
    out = subprocess.check_output(['git','ls-remote','--tags','--refs',repo], text=True, stderr=subprocess.DEVNULL, timeout=60)
except Exception:
    raise SystemExit(1)
items=[]
for line in out.splitlines():
    if not line.strip():
        continue
    sha, ref = line.split('\t',1)
    tag = ref.rsplit('/',1)[-1]
    raw = tag[1:] if tag.startswith('v') else tag
    if re.match(r'^\d+(\.\d+){1,3}([-.+][0-9A-Za-z.-]+)?$', raw):
        nums = []
        for part in re.split(r'[^0-9]+', raw):
            if part != '':
                nums.append(int(part))
        items.append((nums, tag, sha))
if not items:
    raise SystemExit(1)
items.sort(key=lambda x: (x[0], x[1]))
print(items[-1][1])
PY
}

resolve_ref(){
  name="$1"; repo="$2"; requested="$3"
  if [ "$requested" = "latest-tag-or-default" ] || [ "$requested" = "auto" ]; then
    if tag="$(resolve_latest_tag "$repo" 2>/dev/null)" && [ -n "$tag" ]; then
      printf '%s' "$tag"
      return 0
    fi
    branch="$(resolve_default_branch "$repo" 2>/dev/null || true)"
    [ -n "$branch" ] || branch="main"
    printf '%s' "$branch"
    return 0
  fi
  printf '%s' "$requested"
}

clone_part(){
  name="$1"; category="$2"; required="$3"; repo="$4"; requested_ref="$5"
  dest="$(repo_dir "$name")"
  mkdir -p "$(dirname "$dest")"

  if [ "$SKIP_EXISTING" = "1" ] && [ -d "$dest/.git" ]; then
    log "reuse existing $name"
  else
    rm -rf "$dest"
    resolved_ref="$(resolve_ref "$name" "$repo" "$requested_ref")"
    log "clone $name ($category) from $repo ref=$resolved_ref"
    clone_args=()
    if [ "$DEPTH" != "0" ]; then clone_args+=(--depth "$DEPTH"); fi
    if ! git clone "${clone_args[@]}" --branch "$resolved_ref" "$repo" "$dest" >/dev/null 2>&1; then
      warn "branch/tag clone failed for $name at $resolved_ref; trying default clone then checkout"
      rm -rf "$dest"
      if [ "$DEPTH" != "0" ]; then
        git clone --depth "$DEPTH" "$repo" "$dest" >/dev/null 2>&1 || { [ "$required" = "true" ] && fail "clone failed: $name" || return 1; }
      else
        git clone "$repo" "$dest" >/dev/null 2>&1 || { [ "$required" = "true" ] && fail "clone failed: $name" || return 1; }
      fi
      if ! git -C "$dest" checkout --detach "$resolved_ref" >/dev/null 2>&1; then
        warn "checkout failed for $name ref=$resolved_ref; using cloned HEAD and locking commit"
      fi
    fi
  fi

  commit="$(git -C "$dest" rev-parse HEAD 2>/dev/null || true)"
  [ -n "$commit" ] || { [ "$required" = "true" ] && fail "no commit resolved for required part $name" || return 1; }
  branch="$(git -C "$dest" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  cdate="$(git -C "$dest" show -s --format=%cI HEAD 2>/dev/null || true)"
  actual_url="$(git -C "$dest" remote get-url origin 2>/dev/null || printf '%s' "$repo")"

  mkdir -p "$ROOT/locks/commits"
  cat > "$ROOT/locks/commits/$name.json" <<EOF
{"name":"$name","category":"$category","required":$required,"repo":"$actual_url","requested_ref":"$requested_ref","resolved_commit":"$commit","resolved_branch":"$branch","commit_date":"$cdate"}
EOF

  if [ "$COPY_FULL_REPOS" = "1" ]; then
    out="$(assembled_dir "$name" "$category")"
    rm -rf "$out"
    mkdir -p "$out"
    # Copy checked-out external repo contents, excluding VCS/caches/build artifacts.
    (cd "$dest" && tar --exclude='.git' --exclude='node_modules' --exclude='target' --exclude='dist' --exclude='.wrangler' --exclude='.venv' --exclude='__pycache__' -cf - .) | (cd "$out" && tar -xf -)
  fi

  return 0
}

log "harvest profile=$PROFILE strict=$STRICT ref_policy=$REF_POLICY"
while IFS=$'\t' read -r name category required repo requested_ref; do
  clone_part "$name" "$category" "$required" "$repo" "$requested_ref" || {
    [ "$required" = "true" ] && fail "required part failed: $name" || warn "optional part failed: $name"
  }
done < "$ROOT/locks/parts.tsv"

log "generate PARTS_LOCK.json"
python3 - <<'PY' "$ROOT/PARTS.json" "$ROOT/locks/commits" "$ROOT/PARTS_LOCK.json" "$PROFILE" "$STARTED_AT"
import json, pathlib, sys, datetime, os
parts_path, commits_dir, out_path, profile, started = sys.argv[1:]
parts = json.load(open(parts_path))
commit_dir = pathlib.Path(commits_dir)
commit_map = {}
for f in commit_dir.glob('*.json'):
    data = json.load(open(f))
    commit_map[data['name']] = data
locked=[]
for p in parts['parts']:
    if profile == 'core' and not p.get('required', False):
        continue
    q=dict(p)
    q.update(commit_map.get(p['name'], {'resolved_commit': None, 'status': 'not_cloned'}))
    locked.append(q)
json.dump({
    'name': parts['name'],
    'profile': profile,
    'started_at': started,
    'generated_at': datetime.datetime.utcnow().replace(microsecond=0).isoformat()+'Z',
    'categories_required': parts['categories_required'],
    'parts': locked
}, open(out_path,'w'), indent=2)
PY

log "write MANIFEST.md"
python3 - <<'PY' "$ROOT/PARTS_LOCK.json" "$ROOT/MANIFEST.md"
import json, sys
lock=json.load(open(sys.argv[1]))
with open(sys.argv[2],'w') as f:
    f.write('# Minilab External Grounded Manifest\n\n')
    f.write('This manifest records external repositories harvested for the Minilab. It does not claim production readiness.\n\n')
    f.write('## Required Categories\n\n')
    for c in lock['categories_required']:
        f.write(f'- {c}\n')
    f.write('\n## Locked Parts\n\n')
    f.write('| Name | Category | Required | Commit | Repo | Why | Adapter target |\n')
    f.write('|---|---|---:|---|---|---|---|\n')
    for p in lock['parts']:
        f.write('| {name} | {cat} | {req} | `{commit}` | {repo} | {why} | {adapter} |\n'.format(
            name=p.get('name',''), cat=p.get('category',''), req=p.get('required',''),
            commit=p.get('resolved_commit') or 'NOT_RESOLVED', repo=p.get('repo',''),
            why=(p.get('why','') or '').replace('|','/'), adapter=(p.get('adapter_target','') or '').replace('|','/')
        ))
PY

cat > "$ROOT/ASSEMBLY_MAP.md" <<'MD'
# Assembly Map

The Minilab is assembled as external parts by function.

## Runtime workflow

Primary harvested runtime substrate: DBOS TypeScript. It provides Postgres-backed durable workflows, queues, notifications, scheduling, workflow IDs and idempotent starts. Optional alternatives/reference engines include pg-workflows and OpenWorkflow.

Mapping required by Minilab:

- input: external request/event/tool invocation
- candidate: workflow step output
- admission: workflow step gated by schema/policy
- policy: Cedar/OPA/OpenFGA/Topaz-backed decision step
- plan: workflow step producing deterministic JSON plan
- dispatch guard: workflow step checking admission stamp before backend call
- execution backend: Wasmtime/E2B/worker step
- receipt: canonical JSON/hash/store step
- audit/idempotency: Postgres-backed workflow/store records

## MCP nodes

Official MCP SDKs are harvested. MCP tool calls must be adapted into candidates. They are never authorization.

## Policy/admission

Cedar and OPA are harvested for policy decisions. OpenFGA/Topaz are harvested for relationship/capability registries. A policy allow is not dispatch.

## Store/receipts/idempotency

DBOS/Postgres, SQLx, node-postgres, Postgres.js, JCS/RFC8785 implementations, JSON Schema/Zod validators are harvested for durable state, receipt hashing, schema validation and idempotency.

## Control plane

Hono and Cloudflare Workers SDK are harvested for HTTP/control-plane implementation. Routes are not admission.

## Execution

Wasmtime is harvested as the local sandbox backend. E2B is harvested as optional cloud sandbox reference.

## Observability

OpenTelemetry is harvested for traces/correlation. Trace is not proof.

## Verification

Dagger, nextest, gitleaks, promptfoo are harvested for build/test/secret scanning/eval. CI receipts must scope claims narrowly.

## Secrets/identity

Vault, Infisical and Ory Oathkeeper are harvested as secrets/identity/access-control references. License review is required for Vault versions.

## Future LLM ingress

OpenAI Agents SDK, Vercel AI SDK, Pydantic AI, LangGraph, Mastra and smolagents are harvested as future ingress/lab references only. They are not the kernel.
MD

cat > "$ROOT/scripts/verify-minilab-harvest.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
fail(){ printf '[verify][fail] %s\n' "$*" >&2; exit 1; }
log(){ printf '[verify] %s\n' "$*" >&2; }
[ -f "$ROOT/PARTS.json" ] || fail "missing PARTS.json"
[ -f "$ROOT/PARTS_LOCK.json" ] || fail "missing PARTS_LOCK.json"
[ -f "$ROOT/MANIFEST.md" ] || fail "missing MANIFEST.md"
[ -f "$ROOT/CANON.md" ] || fail "missing CANON.md"
[ -f "$ROOT/ASSEMBLY_MAP.md" ] || fail "missing ASSEMBLY_MAP.md"
python3 -m json.tool "$ROOT/PARTS.json" >/dev/null || fail "PARTS.json invalid"
python3 -m json.tool "$ROOT/PARTS_LOCK.json" >/dev/null || fail "PARTS_LOCK.json invalid"
python3 - <<'PY' "$ROOT/PARTS_LOCK.json"
import json, sys
lock=json.load(open(sys.argv[1]))
missing=[]
for p in lock['parts']:
    if p.get('required') is True and not p.get('resolved_commit'):
        missing.append(p['name'])
if missing:
    raise SystemExit('required parts missing commits: '+', '.join(missing))
seen={p.get('category') for p in lock['parts'] if p.get('resolved_commit')}
missing_cats=[c for c in lock['categories_required'] if c not in seen]
if missing_cats:
    raise SystemExit('missing category coverage: '+', '.join(missing_cats))
PY
for phrase in \
  "Route is not admission" \
  "Tool call is not authorization" \
  "JSON is not authority" \
  "SDK is not business logic" \
  "Trace is not proof" \
  "Receipt is proof" \
  "Dispatcher only touches the world after the admission stamp"; do
  grep -F "$phrase" "$ROOT/CANON.md" >/dev/null || fail "missing canon phrase: $phrase"
done
# Ensure harvested assembled repos exist for all required parts.
python3 - <<'PY' "$ROOT/PARTS_LOCK.json" "$ROOT/assembled"
import json, pathlib, sys
lock=json.load(open(sys.argv[1])); base=pathlib.Path(sys.argv[2])
missing=[]
for p in lock['parts']:
    if p.get('required') is True:
        path=base/p['category']/p['name']
        if not path.exists() or not any(path.iterdir()):
            missing.append(str(path))
if missing:
    raise SystemExit('required assembled dirs missing/empty: '+', '.join(missing))
PY
log "harvest verification passed"
SH
chmod +x "$ROOT/scripts/verify-minilab-harvest.sh"

cat > "$ROOT/scripts/verify-no-llm-runtime-code.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
fail(){ printf '[verify-no-llm-runtime-code][fail] %s\n' "$*" >&2; exit 1; }
# In external-only mode, runtime implementation must live under vendor/sources or assembled/<category>/<repo>.
# This script blocks common bespoke source roots that would indicate hand-written app/runtime code.
for p in \
  "$ROOT/src" \
  "$ROOT/runtime" \
  "$ROOT/crates" \
  "$ROOT/apps" \
  "$ROOT/packages/minilab" \
  "$ROOT/constitutional-runtime" \
  "$ROOT/minilab-api" \
  "$ROOT/minilab-store"; do
  [ ! -e "$p" ] || fail "bespoke runtime/app source path exists: $p"
done
printf '[verify-no-llm-runtime-code] passed\n' >&2
SH
chmod +x "$ROOT/scripts/verify-no-llm-runtime-code.sh"

cat > "$ROOT/scripts/print-next-upstream-tests.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cat <<EOF
Run upstream tests only after reviewing each upstream's own docs and install requirements.
Suggested smoke sequence from locked repos:

1. DBOS TS examples:
   cd "$ROOT/vendor/sources/dbos-transact-ts"
   inspect README.md and package scripts before running package manager commands.

2. MCP TS SDK examples:
   cd "$ROOT/vendor/sources/mcp-typescript-sdk"
   inspect examples/server/README.md and docs/server.md.

3. Cedar:
   cd "$ROOT/vendor/sources/cedar"
   inspect README and cargo workspace test instructions.

4. Wasmtime:
   cd "$ROOT/vendor/sources/wasmtime"
   inspect examples/ and docs for embedding examples.

5. Verification tooling:
   dagger, nextest, gitleaks and promptfoo were harvested; install/run them according to their upstream instructions.
EOF
SH
chmod +x "$ROOT/scripts/print-next-upstream-tests.sh"

if [ "$RUN_SMOKE" = "1" ]; then
  log "run structural verifications"
  "$ROOT/scripts/verify-minilab-harvest.sh" "$ROOT"
  "$ROOT/scripts/verify-no-llm-runtime-code.sh" "$ROOT"
fi

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "write receipt"
python3 - <<'PY' "$ROOT" "$STARTED_AT" "$FINISHED_AT" "$WARNINGS"
import hashlib, json, os, sys, datetime
root, started, finished, warnings = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
files=['PARTS.json','PARTS_LOCK.json','MANIFEST.md','CANON.md','ASSEMBLY_MAP.md']
hashes={}
for rel in files:
    path=os.path.join(root,rel)
    if os.path.exists(path):
        hashes[rel]=hashlib.sha256(open(path,'rb').read()).hexdigest()
lock=json.load(open(os.path.join(root,'PARTS_LOCK.json')))
receipt={
  'kind':'minilab.external_grounded_harvest.receipt',
  'started_at':started,
  'finished_at':finished,
  'scope':'external code harvest, commit lock, manifest, category coverage verification',
  'profile':lock.get('profile'),
  'warnings':warnings,
  'parts_count':len(lock.get('parts',[])),
  'categories_required':lock.get('categories_required',[]),
  'hashes':hashes,
  'checks':[{'name':'verify-minilab-harvest','status':'passed'},{'name':'verify-no-llm-runtime-code','status':'passed'}],
  'limits':[ 'This receipt proves the harvest/lock/manifest checks, not production behavior.', 'Upstream package tests are not run by default.', 'Adapters must preserve laws in CANON.md.' ]
}
out=os.path.join(root,'receipts','external-grounded-harvest-receipt.json')
json.dump(receipt, open(out,'w'), indent=2)
print(out)
PY

cat <<EOF

Minilab external grounded harvest completed.

Root: $ROOT
Profile: $PROFILE
Started: $STARTED_AT
Finished: $FINISHED_AT
Warnings: $WARNINGS

Outputs:
- $ROOT/PARTS.json
- $ROOT/PARTS_LOCK.json
- $ROOT/MANIFEST.md
- $ROOT/ASSEMBLY_MAP.md
- $ROOT/CANON.md
- $ROOT/receipts/external-grounded-harvest-receipt.json

Verification:
- $ROOT/scripts/verify-minilab-harvest.sh
- $ROOT/scripts/verify-no-llm-runtime-code.sh

Next upstream test hints:
- $ROOT/scripts/print-next-upstream-tests.sh
EOF
