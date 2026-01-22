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

abort() {
  echo "error: $*" 1>&2
  exit 1
}

if [[ -d $out_dir ]]; then
  abort "output directory already exists: $out_dir"
fi

# Create a temporary working directory.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Build documentation in the temporary directory.
pushd "$tmp_dir"

sed_i() {
  local file
  file=${!#}
  sed "$@" >"$file.tmp"
  mv "$file.tmp" "$file"
}

clean_latex2html() {
  (
    cd "$1"
    rm -f devref.html images.aux images.idx images.log images.pdf images.pl images.tex internals.pl labels.pl manual.html
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
pushd form
git checkout "$repo_rev"
revision=$(git rev-parse HEAD)
version=$(./scripts/git-version-gen.sh -r | sed '2q;d' | sed 's/^v//')
autoreconf -i
mkdir build
pushd build
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
mkdir -p doc/man1
man -Thtml ../doc/form.1 >doc/man1/index.html
man -Tpdf ../doc/form.1 >doc/form.pdf

# Prepare the output directory.
popd && popd && popd
build_dir="$tmp_dir/form/build"
tmp_out_dir="$out_dir.tmp$$"
mkdir -p "$tmp_out_dir"

# Move the documents.
echo "$revision" >"$tmp_out_dir/_REVISION"
echo "$version" >"$tmp_out_dir/_VERSION"
mv "$build_dir/doc/manual/manual" "$tmp_out_dir/manual"
mv "$build_dir/doc/devref/devref" "$tmp_out_dir/devref"
mv "$build_dir/doc/doxygen/html" "$tmp_out_dir/doxygen"
mv "$build_dir/doc/man1" "$tmp_out_dir/man1"
mv "$build_dir/doc/manual/manual.pdf" "$tmp_out_dir/form-$version-manual.pdf"
mv "$build_dir/doc/devref/devref.pdf" "$tmp_out_dir/form-$version-devref.pdf"
mv "$build_dir/doc/doxygen/doxygen.pdf" "$tmp_out_dir/form-$version-doxygen.pdf"
mv "$build_dir/doc/form.pdf" "$tmp_out_dir/form-$version.pdf"
mv "$build_dir/form-$version-manual-html.tar.gz" "$tmp_out_dir/form-$version-manual-html.tar.gz"
mv "$build_dir/form-$version-devref-html.tar.gz" "$tmp_out_dir/form-$version-devref-html.tar.gz"
mv "$build_dir/form-$version-doxygen-html.tar.gz" "$tmp_out_dir/form-$version-doxygen-html.tar.gz"
mv "$build_dir/doc/form.1" "$tmp_out_dir/form.1"

mkdir -p "$(dirname "$out_dir")"
mv "$tmp_out_dir" "$out_dir"
