#!/usr/bin/env bash
# bundle-libs.sh
# Run once locally to populate Libs/ with all required dependencies.
# Requires: git, curl, unzip
#
# Usage:
#   cd /path/to/RepKeeper
#   chmod +x bundle-libs.sh
#   ./bundle-libs.sh
#
# After this runs, the Libs/ folder is fully populated and the addon works
# standalone — no separate Ace3/LibDeflate/etc installs needed.

set -euo pipefail

cd "$(dirname "$0")"

ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

mkdir -p Libs

echo "==> Fetching Ace3..."
git clone --depth 1 https://github.com/WoWUIDev/Ace3.git "$TMP/Ace3" 2>&1 | tail -3 \
  || git clone --depth 1 https://repos.wowace.com/wow/ace3 "$TMP/Ace3"

# Ace3 ships every AceXxx-3.0 module as a folder; copy what we use.
for mod in LibStub CallbackHandler-1.0 \
           AceAddon-3.0 AceEvent-3.0 AceDB-3.0 AceDBOptions-3.0 \
           AceLocale-3.0 AceConsole-3.0 AceHook-3.0 AceTimer-3.0 \
           AceComm-3.0 AceSerializer-3.0 AceGUI-3.0 AceConfig-3.0; do
  if [ -d "$TMP/Ace3/$mod" ]; then
    rm -rf "Libs/$mod"
    cp -r "$TMP/Ace3/$mod" "Libs/$mod"
    echo "    ✓ $mod"
  else
    echo "    ✗ $mod NOT FOUND in Ace3 source"
  fi
done

echo "==> Fetching LibDataBroker-1.1..."
git clone --depth 1 https://github.com/tekkub/libdatabroker-1-1.git "$TMP/LDB"
mkdir -p "Libs/LibDataBroker-1.1"
cp "$TMP/LDB/LibDataBroker-1.1.lua" "Libs/LibDataBroker-1.1/"
echo "    ✓ LibDataBroker-1.1"

echo "==> Fetching LibDBIcon-1.0..."
git clone --depth 1 https://github.com/Nevcairiel/LibDBIcon-1.0.git "$TMP/LDBIcon" 2>&1 | tail -3 \
  || git clone --depth 1 https://repos.wowace.com/wow/libdbicon-1-0 "$TMP/LDBIcon"
mkdir -p "Libs/LibDBIcon-1.0"
if [ -d "$TMP/LDBIcon/LibDBIcon-1.0" ]; then
  cp -r "$TMP/LDBIcon/LibDBIcon-1.0/." "Libs/LibDBIcon-1.0/"
else
  cp -r "$TMP/LDBIcon/." "Libs/LibDBIcon-1.0/"
fi
echo "    ✓ LibDBIcon-1.0"

echo "==> Fetching LibDeflate..."
git clone --depth 1 https://github.com/SafeteeWoW/LibDeflate.git "$TMP/LibDeflate"
mkdir -p "Libs/LibDeflate"
cp "$TMP/LibDeflate/LibDeflate.lua" "Libs/LibDeflate/"
echo "    ✓ LibDeflate"

echo "==> Fetching LibSerialize..."
git clone --depth 1 https://github.com/rossnichols/LibSerialize.git "$TMP/LibSerialize"
mkdir -p "Libs/LibSerialize"
cp "$TMP/LibSerialize/LibSerialize.lua" "Libs/LibSerialize/"
echo "    ✓ LibSerialize"

echo
echo "==> Activating embedded lib loads in TOC..."
# Uncomment the lib block (strip leading '# ' inside the @non-debug@ markers)
python3 - <<'PY'
import re
with open('RepKeeper.toc', 'r', encoding='utf-8') as f:
    toc = f.read()
def strip_comment(m):
    block = m.group(0)
    lines = block.split('\n')
    out = []
    for line in lines:
        if line.startswith('# Libs\\') or line.startswith('# Libs/'):
            out.append(line[2:])
        else:
            out.append(line)
    return '\n'.join(out)
toc = re.sub(r'#@non-debug@.*?#@end-non-debug@', strip_comment, toc, flags=re.DOTALL)
# Drop the Dependencies line since libs are now self-contained
toc = re.sub(r'^## Dependencies:.*$\n', '', toc, flags=re.MULTILINE)
toc = re.sub(r'^## OptionalDeps:.*$\n', '## OptionalDeps: \n', toc, flags=re.MULTILINE)
with open('RepKeeper.toc', 'w', encoding='utf-8') as f:
    f.write(toc)
print("    ✓ TOC updated")
PY

echo
echo "Done. RepKeeper now bundles all libs. Reload UI in WoW."
echo "Folder size:"
du -sh Libs/ 2>/dev/null || true
