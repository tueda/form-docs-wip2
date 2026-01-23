#!/bin/bash
#
# Update the Markdown index page.
#
# Usage:
#   update-index.sh INPUT.json OUTPUT-DIR
#
set -euo pipefail

REPOSITORY=https://github.com/form-dev/form.git

input_json=$1
out_dir=$2

if [[ $input_json != /* ]]; then
  input_json="$PWD/$input_json"
fi

cd "$out_dir"

{
  echo '---'
  echo 'layout: default'
  echo '---'

  jq -r '
    .docs[]
    | "\(.name)\t\(.dir)\t\(.ref)"
  ' <"$input_json" | while IFS=$'\t' read -r name dir ref; do
    version=$(cat "$dir/_VERSION")
    url="${REPOSITORY%.git}/tree/$ref"
    echo "## [$name]($url)"
    if [ -d "$dir/manual" ]; then
      echo "- [FORM $version Reference manual]($dir/manual) (also available in [PDF]($dir/form-$version-manual.pdf) or as an [HTML tarball]($dir/form-$version-manual-html.tar.gz))"
    fi
    if [ -d "$dir/devref" ]; then
      echo "- [FORM $version Developer's reference manual]($dir/devref) (also available in [PDF]($dir/form-$version-devref.pdf) or as an [HTML tarball]($dir/form-$version-devref-html.tar.gz))"
    fi
    if [ -d "$dir/doxygen" ]; then
      echo "- [FORM $version API reference]($dir/doxygen) (also available in [PDF]($dir/form-$version-doxygen.pdf) or as an [HTML tarball]($dir/form-$version-doxygen-html.tar.gz))"
    fi
    if [ -d "$dir/man1" ]; then
      echo "- [FORM $version man page]($dir/man1) (also available in [PDF]($dir/form-$version.pdf) or as the [original man source]($dir/form.1))"
    fi
    echo
  done
} >index.md
