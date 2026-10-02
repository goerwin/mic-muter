#!/bin/bash
set -euo pipefail

# Release notes from commits between previous tag and given tag.
# Groups Conventional Commits by type; needs full clone (fetch-depth: 0).

tag="${1:?usage: release-notes.sh <tag-or-rev>}"

if ! git rev-parse --verify --quiet "${tag}^{commit}" >/dev/null; then
  echo "Ref '$tag' does not resolve to a commit" >&2
  exit 1
fi

# Allow workflow to override repo URL; fallback to origin.
repo_url="${REPO_URL:-$(git config --get remote.origin.url)}"
repo_url="${repo_url%.git}"
repo_url="${repo_url/git@github.com:/https://github.com/}"

previous=$(git describe --tags --abbrev=0 "${tag}^" 2>/dev/null || true)
range="${previous:+$previous..}$tag"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

emit() { printf -- '- %s ([%s](%s/commit/%s))\n' "$2" "$3" "$repo_url" "$3" >>"$tmp/$1"; }

# Keep final commit at EOF; %x1f separator never appears in subjects.
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" ]] && continue
  subject="${line%%$'\x1f'*}"
  hash="${line##*$'\x1f'}"
  subject="${subject//$'\x1f'/ }"
  if [[ "$subject" =~ ^feat(\(.+\))?!?:[[:space:]]+(.+)$ ]]; then
    emit features "${BASH_REMATCH[2]}" "$hash"
  elif [[ "$subject" =~ ^fix(\(.+\))?!?:[[:space:]]+(.+)$ ]]; then
    emit fixes "${BASH_REMATCH[2]}" "$hash"
  else
    emit other "$subject" "$hash"
  fi
done < <(git log --no-merges --pretty=format:'%s%x1f%h' "$range")

notes=""

for section in "Features:features" "Fixes:fixes" "Other changes:other"; do
  [[ -s "$tmp/${section#*:}" ]] || continue
  notes+="### ${section%%:*}"$'\n\n'"$(cat "$tmp/${section#*:}")"$'\n\n'
done

printf '%s' "$notes"