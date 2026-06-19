#!/usr/bin/env bash

set -euo pipefail

tag_prefix="${1:-}"

# SemVer 2.0.0 matcher used for both release-tag detection and tag filtering.
semver_regex='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'

is_semver() {
  local version="$1"
  [[ "$version" =~ $semver_regex ]]
}

get_semver_core() {
  local version="$1"
  echo "${version%%[-+]*}"
}

get_semver_prerelease() {
  local version="$1"
  local core remainder prerelease

  core="$(get_semver_core "$version")"
  remainder="${version#"$core"}"
  prerelease=''

  if [[ "$remainder" == -* ]]; then
    prerelease="${remainder#-}"
    prerelease="${prerelease%%+*}"
  fi

  echo "$prerelease"
}

semver_compare() {
  local left="$1"
  local right="$2"
  local left_core right_core left_prerelease right_prerelease
  local left_major left_minor left_patch right_major right_minor right_patch
  local -a left_parts right_parts
  local i left_id right_id

  # Compare major/minor/patch numerically first, then apply prerelease precedence.
  left_core="$(get_semver_core "$left")"
  right_core="$(get_semver_core "$right")"

  IFS='.' read -r left_major left_minor left_patch <<< "$left_core"
  IFS='.' read -r right_major right_minor right_patch <<< "$right_core"

  if (( 10#$left_major > 10#$right_major )); then
    echo 1
    return
  fi
  if (( 10#$left_major < 10#$right_major )); then
    echo -1
    return
  fi

  if (( 10#$left_minor > 10#$right_minor )); then
    echo 1
    return
  fi
  if (( 10#$left_minor < 10#$right_minor )); then
    echo -1
    return
  fi

  if (( 10#$left_patch > 10#$right_patch )); then
    echo 1
    return
  fi
  if (( 10#$left_patch < 10#$right_patch )); then
    echo -1
    return
  fi

  left_prerelease="$(get_semver_prerelease "$left")"
  right_prerelease="$(get_semver_prerelease "$right")"

  if [[ -z "$left_prerelease" && -z "$right_prerelease" ]]; then
    echo 0
    return
  fi
  if [[ -z "$left_prerelease" ]]; then
    echo 1
    return
  fi
  if [[ -z "$right_prerelease" ]]; then
    echo -1
    return
  fi

  # Prerelease identifiers are compared segment-by-segment per SemVer rules.
  IFS='.' read -r -a left_parts <<< "$left_prerelease"
  IFS='.' read -r -a right_parts <<< "$right_prerelease"

  for (( i = 0; i < ${#left_parts[@]} || i < ${#right_parts[@]}; i++ )); do
    if (( i >= ${#left_parts[@]} )); then
      echo -1
      return
    fi
    if (( i >= ${#right_parts[@]} )); then
      echo 1
      return
    fi

    left_id="${left_parts[i]}"
    right_id="${right_parts[i]}"

    if [[ "$left_id" =~ ^[0-9]+$ && "$right_id" =~ ^[0-9]+$ ]]; then
      if (( 10#$left_id > 10#$right_id )); then
        echo 1
        return
      fi
      if (( 10#$left_id < 10#$right_id )); then
        echo -1
        return
      fi
      continue
    fi

    if [[ "$left_id" =~ ^[0-9]+$ ]]; then
      echo -1
      return
    fi
    if [[ "$right_id" =~ ^[0-9]+$ ]]; then
      echo 1
      return
    fi

    if [[ "$left_id" > "$right_id" ]]; then
      echo 1
      return
    fi
    if [[ "$left_id" < "$right_id" ]]; then
      echo -1
      return
    fi
  done

  echo 0
}

semver_gt() {
  local left="$1"
  local right="$2"
  [[ "$(semver_compare "$left" "$right")" -gt 0 ]]
}

default_branch="${NUGET_VERSION_DEFAULT_BRANCH:-}"
run_number="${NUGET_VERSION_RUN_NUMBER:-}"
ref_type="${NUGET_VERSION_REF_TYPE:-}"
ref_name="${NUGET_VERSION_REF_NAME:-}"

if [[ -z "$default_branch" ]]; then
  echo "NUGET_VERSION_DEFAULT_BRANCH is required" >&2
  exit 1
fi

if [[ -z "$run_number" ]]; then
  echo "NUGET_VERSION_RUN_NUMBER is required" >&2
  exit 1
fi

if [[ "$ref_type" == 'tag' && "$ref_name" == "$tag_prefix"* ]]; then
  release_version="${ref_name#"$tag_prefix"}"
  if is_semver "$release_version"; then
    echo "version=$release_version"
    echo 'is-release=true'
    exit 0
  fi
fi

default_ref=''
# Prefer the remote default branch, but support local-only refs for workflow tests.
if git show-ref --verify --quiet "refs/remotes/origin/$default_branch"; then
  default_ref="refs/remotes/origin/$default_branch"
elif git show-ref --verify --quiet "refs/heads/$default_branch"; then
  default_ref="refs/heads/$default_branch"
else
  echo "Default branch ref not found for '$default_branch'" >&2
  exit 1
fi

# Track only the most recently tagged matching commit. If that commit has multiple
# matching tags, choose the highest SemVer from that same commit.
target_commit=''
selected_version=''

while IFS= read -r tag_name; do
  [[ "$tag_name" == "$tag_prefix"* ]] || continue

  candidate_version="${tag_name#"$tag_prefix"}"
  is_semver "$candidate_version" || continue

  tag_commit="$(git rev-list -n 1 "$tag_name")"
  if ! git merge-base --is-ancestor "$tag_commit" "$default_ref"; then
    continue
  fi

  if [[ -z "$target_commit" ]]; then
    target_commit="$tag_commit"
    selected_version="$candidate_version"
    continue
  fi

  if [[ "$tag_commit" == "$target_commit" ]] && semver_gt "$candidate_version" "$selected_version"; then
    selected_version="$candidate_version"
  fi
done < <(git for-each-ref --sort=-creatordate --format='%(refname:strip=2)' refs/tags)

if [[ -z "$selected_version" ]]; then
  echo "version=0.1.0-alpha.$run_number"
  echo 'is-release=false'
  exit 0
fi

selected_core="$(get_semver_core "$selected_version")"
selected_prerelease="$(get_semver_prerelease "$selected_version")"

if [[ -n "$selected_prerelease" ]]; then
  # For prerelease latest tags, keep X.Y.Z and replace prerelease with alpha.<run>.
  resolved_version="$selected_core-alpha.$run_number"
else
  # For stable latest tags, increment patch and apply alpha.<run>.
  IFS='.' read -r selected_major selected_minor selected_patch <<< "$selected_core"
  resolved_version="$selected_major.$selected_minor.$(( selected_patch + 1 ))-alpha.$run_number"
fi

echo "version=$resolved_version"
echo 'is-release=false'
