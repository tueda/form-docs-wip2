#!/bin/bash
#
# Build the Markdown index page.
#
# Usage:
#   make-index.sh INPUT.json OUTPUT-DIR
#
set -euo pipefail

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
    | "\(.name)\t\(.ref)\t\(.rev)\t\(.url)"
  ' <"$input_json" | while IFS=$'\t' read -r name ref _rev url; do
    version=$(cat "$ref/_VERSION")
    echo "## [$name]($url)"
    echo "- [FORM $version Reference manual]($ref/manual) (also available in [PDF]($ref/form-$version-manual.pdf) or as an [HTML tarball]($ref/form-$version-manual-html.tar.gz))"
    echo "- [FORM $version Developer's reference manual]($ref/devref) (also available in [PDF]($ref/form-$version-devref.pdf) or as an [HTML tarball]($ref/form-$version-devref-html.tar.gz))"
    echo "- [FORM $version API reference]($ref/doxygen) (also available in [PDF]($ref/form-$version-doxygen.pdf) or as an [HTML tarball]($ref/form-$version-doxygen-html.tar.gz))"
    echo "- [Man page for FORM $version]($ref/form.html) (also available in [PDF]($ref/form-$version.pdf) or as a [man page]($ref/form.1))"
    echo
  done
}
