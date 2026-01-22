#!/bin/bash
#
# Generate a JSON list of documentation versions.
#
# Usage:
#   list-docs.sh [options]
#
# Example:
#   list-docs.sh -d master -m v4.3.0 -i v4.2.1 -e v5.0.0-beta.1
#
set -euo pipefail

REPOSITORY=https://github.com/form-dev/form.git

development_branches=()
minimum_version=
include_versions=()
exclude_versions=()

abort() {
  echo "error: $*" 1>&2
  exit 1
}

while getopts 'd:m:i:e:' opt; do
  case "$opt" in
  d) development_branches+=("$OPTARG") ;;
  m) minimum_version="$OPTARG" ;;
  i) include_versions+=("$OPTARG") ;;
  e) exclude_versions+=("$OPTARG") ;;
  *) abort "unknown option: $opt" ;;
  esac
done

get_revision() {
  git ls-remote "$REPOSITORY" "$1" | awk '{print $1}'
}

enum_versions() {
  # NOTE: sort -V requires GNU/recent BSD sort.
  {
    git ls-remote --tags "$REPOSITORY" |
      awk '{print $2}' |
      grep -E 'refs/tags/v[0-9]+' |
      sed -E 's#refs/tags/##; s#\^\{\}##' |
      sort -V |
      {
        if [[ -n $minimum_version ]]; then
          awk -v min_v="$minimum_version" '
            $0 == min_v { found = 1 }
            found { print }
          '
        else
          cat
        fi
      }

    for v in "${include_versions[@]}"; do
      echo "$v"
    done
  } |
    sort -urV |
    awk -v excl_list="${exclude_versions[*]-}" '
      BEGIN {
        split(excl_list, a, " ")
        for (i in a) excl[a[i]] = 1
      }
      {
        if ($0 in excl) next
        print
      }
    '
}

make_item() {
  v=$(get_revision "$2")
  [[ -z $v ]] && abort "cannot find revision for $2"
  jq -n --arg n "$1" --arg r "$2" --arg v "$v" --arg u "${REPOSITORY%.git}/tree/${3:-$v}" \
    '{name:$n, ref:$r, rev:$v, url:$u}'
}

latest_ref=
stable_ref=
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
  for r in "${development_branches[@]}"; do
    if [[ -z $latest_ref ]]; then
      latest_ref="$r"
    fi
    make_item "Nightly Build ($r)" "$r"
  done

  for r in $(enum_versions); do
    if [[ -z $stable_ref && $r != *beta* ]]; then
      stable_ref="$r"
    fi
    make_item "${r#v}" "$r" "$r"
  done
} >"$tmp"
jq -s --arg latest_ref "$latest_ref" --arg stable_ref "$stable_ref" '{docs: ., latest_ref: $latest_ref, stable_ref: $stable_ref}' <"$tmp"
