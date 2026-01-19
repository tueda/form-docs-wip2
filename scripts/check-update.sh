#!/bin/bash
#
# Check for updates.
#
# Usage:
#   check-update.sh
#
set -eu
set -o pipefail

REPOSITORY=https://github.com/form-dev/form.git
DEVELOPMENT_BRANCHES=(master)
MINIMUM_VERSION=4.3.1
EXCLUDE=(v5.0.0-beta.1)
DOCUMENT_OUTPUT_DIR=docs

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
err=false

get_revision() {
  git ls-remote $REPOSITORY "$1" | awk '{print $1}'
}

enum_versions() {
  exclude_re=$(printf '|%s' "${EXCLUDE[@]}")
  exclude_re=${exclude_re#|}
  git ls-remote --tags $REPOSITORY |
    awk '{print $2}' |
    grep -E 'refs/tags/v[0-9]+' |
    sed -E 's#refs/tags/##; s#\^\{\}##' |
    sort -V |
    awk -v min_v="v$MINIMUM_VERSION" -v excl="$exclude_re" '
      $0 == min_v { flag = 1 }
      flag {
        if (excl != "" && $0 ~ ("^(" excl ")$")) next
      print
    }
    '
}

git_commit() {
  git add -u
  if [ -n "$(git status --porcelain)" ]; then
    if ! pre-commit run; then
      git add -u
      pre-commit run
    fi
    git commit -m "docs(auto): update $1"
  fi
}

# TODO

for v in "${DEVELOPMENT_BRANCHES[@]}"; do
  echo "$v"
done
for v in $(enum_versions); do
  echo "$v"
done

echo "script_dir=$script_dir"
echo "DOCUMENT_OUTPUT_DIR=$DOCUMENT_OUTPUT_DIR"

if $err; then
  exit 1
fi
