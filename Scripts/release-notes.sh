#!/bin/bash
set -euo pipefail

# Prints release notes for the given tag, derived from the commits between it and
# the previous version tag. GitHub's own generated notes list merged pull
# requests, so they are empty for a repository whose commits land straight on
# main. Conventional Commit subjects are grouped by type; anything else is listed
# verbatim.
#
# Requires a full clone (actions/checkout: fetch-depth: 0); a shallow one cannot
# see the previous tag.

tag="${1:?usage: release-notes.sh vX.Y.Z}"

if ! git rev-parse --verify --quiet "$tag^{commit}" >/dev/null; then
  echo "Tag '$tag' does not resolve to a commit" >&2
  exit 1
fi

# Overridable so the workflow can supply an explicit URL; otherwise taken from
# the origin remote, which covers local runs too.
repo_url="${REPO_URL:-$(git config --get remote.origin.url)}"
repo_url="${repo_url%.git}"
repo_url="${repo_url/git@github.com:/https://github.com/}"

previous=$(git describe --tags --abbrev=0 "${tag}^" 2>/dev/null || true)
range="${previous:+$previous..}$tag"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

emit() { printf -- '- %s ([%s](%s/commit/%s))\n' "$2" "$3" "$repo_url" "$3" >>"$tmp/$1"; }

# `read` returns non-zero at EOF, so the || guard is what keeps the final commit.
# The %x1f separator cannot appear in a commit subject.
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