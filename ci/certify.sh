#!/usr/bin/env bash
# Certify a canary's fix+reference-carrying bugs: for each, the reference PoC must WIN on the
# vulnerable snapshot and DIE on the fixed variant — the lab's `counterfactual` verdict must be
# `confirmed` (the fix used IS this bug's). This proves the canary end-to-end (bug exploitable,
# patch kills it,
# judge reproduces it), once, instead of trusting curation prose.
#
# Usage:
#   ci/certify.sh <canary-dir>
#
# Environment:
#   LAB_CMD           — how to invoke the lab CLI (default: "illumina-lab"; locally e.g.
#                       "uv run --directory /path/to/illumina-lab illumina-lab")
#   CERTIFY_WORKSPACE — skip reconstruction: replay inside this existing PoC workspace
#                       (development fast path; CI always reconstructs from the canary data)
#   STRIP / TARGET_DIR — patch application layout (defaults: 3 / lib/target, the PoC
#                       workspace layout; use 1 / . for a full target clone)
#   SUBDIR            — the in-repo subtree materialized as the workspace target
#                       (default: canary.json's target_subdir, else barretenberg/sol)
#
# Reconstruction (no workspace given): assemble a fresh Foundry workspace from the canary's
# reference/ files — the target subtree at lib/target (sparse, blob-filtered fetch of the
# snapshot) and every dependency pinned in reference/foundry.toml. Everything runs on scratch
# dirs; no archived artifacts are modified. In reconstruction mode each bug's reference/
# refreshes the workspace's test/ before its replay (one PoC per bug).
set -euo pipefail

CANARY=${1:?usage: ci/certify.sh <canary-dir>}
CANARY=$(cd "$CANARY" && pwd)  # absolute: uv run --directory changes CWD before the lab CLI runs
LAB_CMD=${LAB_CMD:-illumina-lab}
STRIP=${STRIP:-3}
TARGET_DIR=${TARGET_DIR:-lib/target}

SNAPSHOT=$(python3 -c "import json; print(json.load(open('$CANARY/canary.json'))['snapshot_sha'])")
REPO=$(python3 -c "import json; print(json.load(open('$CANARY/canary.json'))['links'][0])")
SUBDIR=${SUBDIR:-$(python3 -c "import json; print(json.load(open('$CANARY/canary.json')).get('target_subdir', 'barretenberg/sol'))")}
BUGS=$(python3 -c "
import json
for b in json.load(open('$CANARY/bugs.json')):
    if b.get('fix') and b.get('reference_poc'):
        print(b['id'], b['fix'], b['reference_poc'])
")
[ -n "$BUGS" ] || { echo "certify: no bugs with fix + reference_poc in $CANARY/bugs.json"; exit 2; }

WORK=${CERTIFY_WORKSPACE:-}
RECONSTRUCTED=""
if [ -z "$WORK" ]; then
    RECONSTRUCTED=1
    WORK=$(mktemp -d /tmp/canary-certify-XXXX)
    echo "certify: reconstructing workspace in $WORK"
    REF=$(echo "$BUGS" | head -1 | awk '{print $3}')
    cp "$CANARY/$REF/foundry.toml" "$WORK/foundry.toml"

    FULL=$(mktemp -d /tmp/canary-target-XXXX)
    git init -q "$FULL"
    git -C "$FULL" remote add origin "$REPO"
    git -C "$FULL" sparse-checkout set "$SUBDIR"
    git -C "$FULL" fetch -q --depth=1 --filter=blob:none origin "$SNAPSHOT"
    git -C "$FULL" checkout -q --detach FETCH_HEAD
    mkdir -p "$WORK/lib/target"
    cp -r "$FULL/$SUBDIR/." "$WORK/lib/target/"

    # every dependency declared in the reference foundry.toml (forge-std, OpenZeppelin, …)
    python3 - "$WORK/foundry.toml" <<'EOF' | while read -r DEP_NAME DEP_GIT DEP_REV DEP_VER; do
import re, sys
text = open(sys.argv[1]).read()
for m in re.finditer(r'([\w.-]+)\s*=\s*\{\s*version\s*=\s*"([^"]+)",\s*git\s*=\s*"([^"]+)",\s*rev\s*=\s*"([^"]+)"', text):
    print(m.group(1), m.group(3), m.group(4), m.group(2))
EOF
        DEP="$WORK/dependencies/$DEP_NAME-$DEP_VER"
        echo "certify: fetching $DEP_NAME@$DEP_VER"
        git init -q "$DEP"
        git -C "$DEP" remote add origin "$DEP_GIT"
        git -C "$DEP" fetch -q --depth=1 origin "$DEP_REV"
        git -C "$DEP" checkout -q --detach FETCH_HEAD
    done
fi

FAILED=0
while read -r BUG FIX REF; do
    [ -n "$BUG" ] || continue
    if [ -n "$RECONSTRUCTED" ]; then
        rm -rf "$WORK/test" && mkdir -p "$WORK/test"
        find "$CANARY/$REF" -maxdepth 1 -name '*.sol' -exec cp {} "$WORK/test/" \;
    fi
    echo "certify: $BUG — counterfactual replay"
    VERDICT=$($LAB_CMD counterfactual "$WORK" --patch "$CANARY/$FIX" --strip "$STRIP" --target-dir "$TARGET_DIR" \
        | python3 -c "import json,sys; print(json.load(sys.stdin)['verdict'])" || true)
    if [ "$VERDICT" = "confirmed" ]; then
        echo "certify: $BUG — CERTIFIED (wins on vulnerable, dies on fixed)"
    else
        echo "certify: $BUG — FAILED (verdict: $VERDICT)"
        FAILED=1
    fi
done <<< "$BUGS"
exit "$FAILED"
