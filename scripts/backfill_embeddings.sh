#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# backfill_embeddings.sh — Vectoriza (Gemini) todas las vacantes y perfiles que
# todavía no tienen embedding, llamando a las Edge Functions generate-job-embedding
# y generate-embedding. Idempotente: solo toca filas con embedding NULL.
#
# Uso:
#   SUPABASE_ANON_KEY="eyJ..." ./scripts/backfill_embeddings.sh
#
# Requiere: curl. El proyecto está fijo abajo (PROJECT_REF).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT_REF="qclipzefqndcefwwixdy"
BASE="https://${PROJECT_REF}.supabase.co"
REST="${BASE}/rest/v1"
FN="${BASE}/functions/v1"
KEY="${SUPABASE_ANON_KEY:?Falta SUPABASE_ANON_KEY en el entorno}"
SLEEP="${SLEEP:-0.4}"   # pausa entre llamadas para respetar rate limits de Gemini

auth=(-H "apikey: ${KEY}" -H "Authorization: Bearer ${KEY}")

backfill() {
  local label="$1" table="$2" col="$3" fn="$4" idparam="$5" extra="$6"
  echo "── ${label} ──"
  # Trae hasta 1000 ids con el embedding en NULL
  local ids
  ids=$(curl -s "${REST}/${table}?${col}=is.null${extra}&select=id&limit=1000" "${auth[@]}" \
    | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//')
  if [ -z "${ids}" ]; then echo "  (nada que hacer)"; return; fi
  local ok=0 fail=0
  while IFS= read -r id; do
    [ -z "${id}" ] && continue
    local r
    r=$(curl -s -X POST "${FN}/${fn}" "${auth[@]}" -H "Content-Type: application/json" \
      -d "{\"${idparam}\":\"${id}\"}")
    if echo "${r}" | grep -q '"success":true'; then
      ok=$((ok+1)); echo "  ✅ ${id}"
    else
      fail=$((fail+1)); echo "  ❌ ${id} -> ${r}"
    fi
    sleep "${SLEEP}"
  done <<< "${ids}"
  echo "  → ${label}: ${ok} ok, ${fail} con error"
}

# Perfiles: solo los que tienen headline (si no, el texto queda vacío y falla)
backfill "Perfiles"  "users" "profile_embedding" "generate-embedding"     "user_id" "&headline=not.is.null"
# Vacantes: todas las que tengan embedding NULL
backfill "Vacantes"  "jobs"  "embedding"          "generate-job-embedding" "job_id"  ""

echo "Listo."
