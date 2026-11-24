# @author: Jet Qian
# @version: V1.0.0
# @updated: 2026-11-19
# @comment: paths and identifiers of the automation environment itself

*** Variables ***
# Template. Copy this file to variables/ and fill in your own testbed values.

# The label of the result folder. The convention of this project is to give
# every run its own label, so the runs do not write over each other:
#   --variable VERSION:run_20261119_1532 -d result/run_20261119_1532
${VERSION}    01.02.008

# Where the run writes its result. The libraries (ViperSSH, ViperGnmi,
# AutomationFlow) put their log files below it, one folder per suite.
${RESULT_ROOT_PATH}    ${EXECDIR}${/}result${/}${VERSION}

# gnmic on the gNMI client host. Not only a path, the whole prefix that host
# needs, e.g. docker run --network host --rm ghcr.io/openconfig/gnmic
# ViperGnmi falls back to "gnmic" when this is not declared.
${GNMIC_BIN}    gnmic
