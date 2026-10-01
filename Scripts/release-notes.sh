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

previous=$(git describe --tags --abbrev=0 "${tag}^" 2>/dev/null || true)
range="${previous:+$previous..}$tag"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# `read` returns non-zero at EOF, so the || guard is what keeps the final commit.
while IFS= read -r subject || [ -n "$subject" ]; do
  [[ -z "$subject" ]] && continue
  if [[ "$subject" =~ ^feat(\(.+\))?!?:[[:space:]]+(.+)$ ]]; then
    printf -- '- %s\n' "${BASH_REMATCH[2]}" >>"$tmp/features"
  elif [[ "$subject" =~ ^fix(\(.+\))?!?:[[:space:]]+(.+)$ ]]; then
    printf -- '- %s\n' "${BASH_REMATCH[2]}" >>"$tmp/fixes"
  else
    printf -- '- %s\n' "$subject" >>"$tmp/other"
  fi
done < <(git log --no-merges --pretty=format:'%s' "$range")

if [[ -n "$previous" ]]; then
  notes="_Changes since ${previous}._"$'\n\n'
else
  notes="_All commits in this release._"$'\n\n'
fi

for section in "Features:features" "Fixes:fixes" "Other changes:other"; do
  [[ -s "$tmp/${section#*:}" ]] || continue
  notes+="### ${section%%:*}"$'\n\n'"$(cat "$tmp/${section#*:}")"$'\n\n'
done

printf '%s' "$notes"