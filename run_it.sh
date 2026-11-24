#!/usr/bin/env bash
#
# Run the whole IT campaign: the environment check first, then the test items.
#
# The run gets its own folder under result/, so the runs do not write over
# each other. Every argument is handed over to Robot, so the usual options
# work as well:
#
#   ./run_it.sh                 the whole campaign
#   ./run_it.sh -e BENCH        without the cases that need the bench
#   ./run_it.sh --suite PAB-016 only the suites that match
#
set -eu

cd "$(dirname "$0")"

RUN="run_$(date +%Y%m%d_%H%M%S)"
VERSION="$RUN"

# The DUT has to be there before the campaign starts. It disappears from time
# to time (it reboots itself), and a campaign that runs into a missing DUT
# turns every single case red instead of saying what is wrong.
DUT_HOST=$(awk '$1 == "&{SSH_DUT_IT}" {
    for (i = 2; i <= NF; i++) {
        if ($i ~ /^host=/) {
            sub(/^host=/, "", $i)
            print $i
            exit
        }
    }
}' variables/dut_variables.robot)
ping_dut() {
    if [[ "${DUT_HOST}" == *:* ]]; then
        ping -6 -c 1 -W 2 "${DUT_HOST}"
    else
        ping -c 1 -W 2 "${DUT_HOST}"
    fi
}
if [ -n "${DUT_HOST:-}" ]; then
    echo "=== the DUT ${DUT_HOST} has to answer before the campaign starts"
    UP=0
    for _ in $(seq 1 30); do
        if ping_dut >/dev/null 2>&1; then
            UP=1
            break
        fi
        sleep 10
    done
    if [ "${UP}" -eq 0 ]; then
        echo "!!! the DUT ${DUT_HOST} does not answer, the campaign is not started"
        exit 1
    fi
fi

echo "=== the campaign runs into result/${VERSION}"
exec .venv/bin/robotcode robot \
    --variable VERSION:"$VERSION" \
    --output-dir "result/${VERSION}" \
    "$@" \
    IT_ENV IT
