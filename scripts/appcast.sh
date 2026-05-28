#!/usr/bin/env bash
# Append a signed Sparkle <item> to the appcast (newest-first), then validate.
#
# Usage: scripts/appcast.sh <shortVersion> <build> <url> <edSignature> <length> [appcastPath]
set -euo pipefail

if [[ $# -lt 5 ]]; then
    echo "Usage: $0 <shortVersion> <build> <url> <edSignature> <length> [appcastPath]" >&2
    exit 1
fi

SHORT="$1"
BUILD="$2"
URL="$3"
SIG="$4"
LEN="$5"
APPCAST="${6:-docs/appcast.xml}"
MIN_OS="14.0"
PUBDATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

ITEM=$(cat <<EOF
    <item>
      <title>${SHORT}</title>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${SHORT}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_OS}</sparkle:minimumSystemVersion>
      <pubDate>${PUBDATE}</pubDate>
      <enclosure url="${URL}" sparkle:edSignature="${SIG}" length="${LEN}" type="application/octet-stream"/>
    </item>
EOF
)

# Insert the new item directly after the marker (BSD sed 'r' reads a file).
TMP_ITEM="$(mktemp)"
trap 'rm -f "$TMP_ITEM" "$APPCAST.tmp"' EXIT
printf '%s\n' "$ITEM" > "$TMP_ITEM"
sed -e "/<!-- BEGIN ITEMS -->/r $TMP_ITEM" "$APPCAST" > "$APPCAST.tmp"
mv "$APPCAST.tmp" "$APPCAST"

xmllint --noout "$APPCAST"
echo "Added ${SHORT} (build ${BUILD}) to ${APPCAST}"
