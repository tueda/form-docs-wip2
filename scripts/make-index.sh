#!/bin/bash
#
# Build the index page.
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
if [[ $out_dir != /* ]]; then
  out_dir="$PWD/$out_dir"
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
    echo "- [FORM $version Reference manual]($ref/manual) (also in [PDF]($ref/form-$version-manual.pdf) or [an HTML tarball]($ref/form-$version-manual-html.tar.gz))"
    echo "- [FORM $version Developer's reference manual]($ref/devref) (also in [PDF]($ref/form-$version-devref.pdf) or [an HTML tarball]($ref/form-$version-devref-html.tar.gz))"
    echo "- [FORM $version API reference]($ref/doxygen) (also in [PDF]($ref/form-$version-doxygen.pdf) or [an HTML tarball]($ref/form-$version-doxygen-html.tar.gz))"
    echo "- [Manpage of FORM $version]($ref/form.html) (also in [PDF]($ref/form-$version.pdf) or [a Manfile]($ref/form.1))"
  done
}
