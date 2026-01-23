#!/bin/bash
#
# Generate a JSON-formatted list of documentation versions.
#
# Usage:
#   list-docs.sh [options]
#
# Options:
#   -d <branch>   Specify a development branch to include (repeatable).
#   -m <version>  Specify the minimum version to include (e.g., v4.2.0).
#   -i <version>  Specify an additional version to include (repeatable).
#   -e <version>  Specify a version to exclude (repeatable).
#   -s            Include the latest stable release as "stable".
#   -l            Include the latest development version as "latest".
#
# Example:
#   list-docs.sh -d master -m v4.3.0 -i v4.2.1 -e v5.0.0-beta.1
#
set -euo pipefail

REPOSITORY=https://github.com/form-dev/form.git

abort() {
  echo "error: $*" 1>&2
  exit 1
}

development_branches=()
minimum_version=
include_versions=()
exclude_versions=()
show_stable=false
show_latest=false

while getopts 'd:m:i:e:sl' opt; do
  case "$opt" in
  d) development_branches+=("$OPTARG") ;;
  m) minimum_version="$OPTARG" ;;
  i) include_versions+=("$OPTARG") ;;
  e) exclude_versions+=("$OPTARG") ;;
  s) show_stable=: ;;
  l) show_latest=: ;;
  *) abort "unknown option: $opt" ;;
  esac
done

get_revision() {
  ref="$1"
  result=$(git ls-remote "$REPOSITORY" "$ref" | awk '{print $1}')
  [[ -z $result ]] && abort "cannot find revision for $ref"
  echo "$result"
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
  jq -n --arg name "$1" --arg dir "$2" --arg ref "$3" --argjson dev "$4" \
    '{name: $name, dir: $dir, ref: $ref, dev: $dev}'
}

{
  if $show_latest; then
    for r in "${development_branches[@]}"; do
      make_item "Latest ($r branch)" latest "$(get_revision "$r")" false
      break
    done
  fi

  if $show_stable; then
    for r in $(enum_versions); do
      if [[ $r != *beta* ]]; then
        make_item "Stable (${r#v})" stable "$r" false
        break
      fi
    done
  fi

  for r in "${development_branches[@]}"; do
    make_item "Nightly Build ($r branch)" "$r" "$(get_revision "$r")" true
  done

  for r in $(enum_versions); do
    make_item "${r#v}" "$r" "$r" false
  done
} | jq -s '{docs: .}'
