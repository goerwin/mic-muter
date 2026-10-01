#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: ./Scripts/release.sh <patch|minor|major>" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

bump="$1"
case "$bump" in
  patch|minor|major) ;;
  *)
    usage
    exit 2
    ;;
esac

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run this script from inside the Git repository." >&2
  exit 1
}
cd "$repo_root"

if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "Working tree is not clean. Commit or stash your changes first." >&2
  exit 1
fi

remote=origin
remote_url="$(git remote get-url "$remote" 2>/dev/null)" || {
  echo "Git remote '$remote' is not configured." >&2
  exit 1
}

git fetch --tags "$remote"

latest_tag=""
while IFS= read -r tag; do
  if [[ "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    latest_tag="$tag"
    break
  fi
done < <(git tag --list 'v[0-9]*' --sort=-version:refname)

if [[ -z "$latest_tag" ]]; then
  echo "No stable vMAJOR.MINOR.PATCH tag found. Create the first release tag manually." >&2
  exit 1
fi

if ! git merge-base --is-ancestor "$latest_tag" HEAD; then
  echo "Latest release tag '$latest_tag' is not in the current commit history." >&2
  echo "Switch to or merge the latest release branch before releasing." >&2
  exit 1
fi

IFS=. read -r major minor patch <<< "${latest_tag#v}"
case "$bump" in
  patch) patch=$((10#$patch + 1)) ;;
  minor)
    minor=$((10#$minor + 1))
    patch=0
    ;;
  major)
    major=$((10#$major + 1))
    minor=0
    patch=0
    ;;
esac

new_tag="v$major.$minor.$patch"
if git show-ref --verify --quiet "refs/tags/$new_tag"; then
  echo "Tag '$new_tag' already exists locally." >&2
  exit 1
fi

branch="$(git symbolic-ref --quiet --short HEAD || printf 'detached HEAD')"
commit="$(git log -1 --format='%h %s')"

printf '\nRelease confirmation\n'
printf '  Change:     %s after %s\n' "$bump" "$latest_tag"
printf '  New tag:    %s\n' "$new_tag"
printf '  Commit:     %s\n' "$commit"
printf '  Branch:     %s\n' "$branch"
printf '  Destination: %s (%s)\n' "$remote" "$remote_url"
printf '\nPushing this tag starts the GitHub release workflow.\n'
printf 'Proceed? [y/N] '
IFS= read -r answer || answer=""

case "$answer" in
  y|Y|yes|YES|Yes) ;;
  *)
    echo "Cancelled. No tag was created or pushed."
    exit 0
    ;;
esac

git tag -a "$new_tag" -m "Release $new_tag"
if ! git push "$remote" "refs/tags/$new_tag:refs/tags/$new_tag"; then
  git tag -d "$new_tag" >/dev/null 2>&1 || true
  echo "Push failed. Removed local tag '$new_tag'; you can retry after fixing the issue." >&2
  exit 1
fi

echo "Pushed $new_tag. GitHub Actions will build the release."
