#!/bin/bash
#
# Build documentation.
#
# Usage:
#   make-docs.sh REPO-REVISION OUTPUT-DIR
#
set -euo pipefail

REPOSITORY=https://github.com/form-dev/form.git

repo_rev=$1
out_dir=$2

# Convert the output directory to an absolute path.
if [[ $out_dir != /* ]]; then
  out_dir="$PWD/$out_dir"
fi

# Create a temporary working directory.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Build documentation in the temporary directory.
cd "$tmp_dir"

sed_i() {
  local file
  file=${!#}
  sed "$@" >"$file.tmp"
  mv "$file.tmp" "$file"
}

clean_latex2html() {
  (
    cd "$1"
    rm -f images.aux images.idx images.log images.pdf images.pl images.tex internals.pl labels.pl
    if [ -f WARNINGS ]; then
      mv WARNINGS _WARNINGS
    fi
  )
}

make_tarball() {
  cp -R "$1" "$2"
  tar -c "$2"/* | gzip -c -9 >"$2.tar.gz"
  rm -R "$2"
}

git clone $REPOSITORY
cd form
git checkout "$repo_rev"
version=$(./scripts/git-version-gen.sh -r | sed '2q;d' | sed 's/^v//')
autoreconf -i
mkdir build
cd build
../configure --disable-dependency-tracking --disable-scalar --disable-threaded
sed_i 's/^\(CASE_SENSE_NAMES\s*=\s*\)YES/\1NO/' doc/doxygen/DoxyfileHTML
sed_i 's/^\(HAVE_DOT\s*=\s*\)NO/\1YES/' doc/doxygen/DoxyfileHTML
sed_i 's/^\(CALL_GRAPH\s*=\s*\)NO/\1YES/' doc/doxygen/DoxyfileHTML
sed_i 's/^\(HAVE_DOT\s*=\s*\)NO/\1YES/' doc/doxygen/DoxyfilePDFLATEX
sed_i 's/^\(CALL_GRAPH\s*=\s*\)NO/\1YES/' doc/doxygen/DoxyfilePDFLATEX
sed_i 's/^\(DOT_IMAGE_FORMAT\s*=\s*\)\(.*\)/\1pdf/' doc/doxygen/DoxyfilePDFLATEX
make pdf
make -C doc/manual latex2html
clean_latex2html doc/manual/manual
make_tarball doc/manual/manual "form-$version-manual-html"
make -C doc/devref latex2html
clean_latex2html doc/devref/devref
make_tarball doc/devref/devref "form-$version-devref-html"
make -C doc/doxygen html
make_tarball doc/doxygen/html "form-$version-doxygen-html"
cp ../doc/form.1 doc/form.1
man -Thtml ../doc/form.1 >doc/form.html
man -Tpdf ../doc/form.1 >doc/form.pdf

# Prepare the output directory.
mkdir -p "$out_dir"

# Move the documents.
git rev-parse HEAD >"$out_dir/_REVISION"
echo "$version" >"$out_dir/_VERSION"
mv doc/manual/manual.pdf "$out_dir/form-$version-manual.pdf"
mv doc/devref/devref.pdf "$out_dir/form-$version-devref.pdf"
mv doc/doxygen/doxygen.pdf "$out_dir/form-$version-doxygen.pdf"
mv "form-$version-manual-html.tar.gz" "$out_dir/form-$version-manual-html.tar.gz"
mv "form-$version-devref-html.tar.gz" "$out_dir/form-$version-devref-html.tar.gz"
mv "form-$version-doxygen-html.tar.gz" "$out_dir/form-$version-doxygen-html.tar.gz"
mv doc/manual/manual "$out_dir/manual"
mv doc/devref/devref "$out_dir/devref"
mv doc/doxygen/html "$out_dir/doxygen"
mv doc/form.1 "$out_dir/form.1"
mv doc/form.html "$out_dir/form.html"
mv doc/form.pdf "$out_dir/form-$version.pdf"
