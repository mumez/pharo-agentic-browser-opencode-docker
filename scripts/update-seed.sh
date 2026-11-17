#!/bin/bash
# Bring the host-side agentic-browser/ (ab-settings.json, topic-template/) up
# to date with the seed baked into this image, for setups created by an
# earlier image version. seed-agentic-browser.sh only fills in missing files
# at startup; this script is run manually to pick up seed changes.
#
# - ab-settings.json: merged with jq. Keys new in the seed are added; values
#   you already have are kept. With --replace, the seed file is copied as is.
# - topic-template/: each seed file that differs from yours is copied over it.
#   Files that exist only on your side are left alone.
#
# Anything changed is backed up first: ab-settings.json -> ab-settings.json.orig,
# topic-template/<file> -> topic-template.orig/<file>. Backups go outside
# topic-template/ so they aren't copied into new topics. If a backup from an
# earlier run exists, a timestamp is appended (.orig.<YYYYmmdd-HHMMSS>).
#
# Usage: ab-update-seed [--dry-run] [--replace]
set -euo pipefail

SEED="${AGENTIC_BROWSER_SEED_DIR:-/opt/agentic-browser-seed}"
DEST="${PHARO_HOME:-/root/smalltalk-interop}/agentic-browser"
STAMP="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=false
REPLACE=false
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=true ;;
    --replace) REPLACE=true ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: ${arg}" >&2; exit 2 ;;
  esac
done

backup_path() {
  if [ -e "$1.orig" ]; then echo "$1.orig.${STAMP}"; else echo "$1.orig"; fi
}

run() {
  if "${DRY_RUN}"; then echo "  (dry-run) $*"; else "$@"; fi
}

changed=0

# ab-settings.json
seed_settings="${SEED}/ab-settings.json"
dest_settings="${DEST}/ab-settings.json"
if [ -f "${seed_settings}" ]; then
  if [ ! -e "${dest_settings}" ]; then
    echo "add      ab-settings.json"
    run cp "${seed_settings}" "${dest_settings}"
    changed=1
  else
    tmp="$(mktemp)"
    trap 'rm -f "${tmp}"' EXIT
    if "${REPLACE}"; then
      cp "${seed_settings}" "${tmp}"
    else
      # Seed first, yours second: your values win, new seed keys are added.
      jq -s '.[0] * .[1]' "${seed_settings}" "${dest_settings}" > "${tmp}"
    fi
    if jq -e -s '.[0] == .[1]' "${tmp}" "${dest_settings}" > /dev/null; then
      echo "same     ab-settings.json"
    else
      bak="$(backup_path "${dest_settings}")"
      echo "update   ab-settings.json (backup: ${bak#"${DEST}"/})"
      if "${DRY_RUN}"; then
        diff <(jq -S . "${dest_settings}") <(jq -S . "${tmp}") | sed 's/^/    /' || true
      else
        cp -p "${dest_settings}" "${bak}"
        cp "${tmp}" "${dest_settings}"
      fi
      changed=1
    fi
  fi
fi

# topic-template/
seed_tpl="${SEED}/topic-template"
dest_tpl="${DEST}/topic-template"
tpl_backup="$(backup_path "${dest_tpl}")"
if [ -d "${seed_tpl}" ]; then
  while IFS= read -r -d '' file; do
    rel="${file#"${seed_tpl}"/}"
    target="${dest_tpl}/${rel}"
    if [ ! -e "${target}" ]; then
      echo "add      topic-template/${rel}"
      run mkdir -p "$(dirname "${target}")"
      run cp -p "${file}" "${target}"
      changed=1
    elif cmp -s "${file}" "${target}"; then
      :
    else
      echo "update   topic-template/${rel} (backup: ${tpl_backup#"${DEST}"/}/${rel})"
      run mkdir -p "$(dirname "${tpl_backup}/${rel}")"
      run cp -p "${target}" "${tpl_backup}/${rel}"
      run cp -p "${file}" "${target}"
      changed=1
    fi
  done < <(find "${seed_tpl}" -type f -print0 | sort -z)
fi

if [ "${changed}" -eq 0 ]; then
  echo "Already up to date."
elif "${DRY_RUN}"; then
  echo "Dry run: nothing was changed."
else
  echo "Done. Restart the container so AgenticBrowser reloads ab-settings.json."
  echo "Existing topics keep their own copies; only new topics use the updated template."
fi
