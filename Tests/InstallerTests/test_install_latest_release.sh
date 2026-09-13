#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$TEST_DIR/bin"

cat > "$TEST_DIR/bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"/releases/latest"* ]]; then
  printf '%s' '{"assets":[{"name":"PRPulseApp.dmg","browser_download_url":"https://example.invalid/PRPulseApp.dmg"}]}'
  exit 0
fi

exit 1
SCRIPT

cat > "$TEST_DIR/bin/hdiutil" <<'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT

chmod +x "$TEST_DIR/bin/curl" "$TEST_DIR/bin/hdiutil"

set +e
OUTPUT="$(PATH="$TEST_DIR/bin:$PATH" OSTYPE=darwin bash "$PROJECT_DIR/scripts/install_latest_release.sh" bhanurp/prpulse 2>&1)"
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  echo "expected mocked install to stop at hdiutil" >&2
  exit 1
fi

if [[ "$OUTPUT" != *"Downloading PRPulseApp.dmg..."* ]]; then
  echo "expected installer to select the DMG asset before mounting it" >&2
  echo "$OUTPUT" >&2
  exit 1
fi
