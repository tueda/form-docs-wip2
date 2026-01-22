#!/bin/bash
#
# Update the Markdown index page.
#
# Usage:
#   update-index.sh INPUT.json OUTPUT-DIR
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
    echo "- [FORM $version man page]($ref/man1) (also available in [PDF]($ref/form-$version.pdf) or as the [original man source]($ref/form.1))"
    echo
  done
} >index.md

make_redirect() {
  name=$1
  target=$2
  mkdir -p "$name"
  for subdir in manual devref doxygen man1; do
    cat >"$name/$subdir.md" <<END
---
permalink: /$name/$subdir/
redirect_to: /$target/$subdir/
---
END
  done
}

make_redirect latest "$(jq -r '.latest_ref' "$input_json")"
make_redirect stable "$(jq -r '.stable_ref' "$input_json")"
