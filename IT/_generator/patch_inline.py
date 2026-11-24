"""Use the inline read for the labels that are not at the start of a line.

Some commands print everything on one line, so the label is in the middle of
it and the line anchored read does not find it:

    state=2 name=ON_HOLD
    palGetNorthAfeInputTargetTcp success (value=33.099998 dBmV)
"""

import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
FILES = ["sheet_pab.py", "sheet_alignment.py", "sheet_asc.py",
         "sheet_cust_facing.py", "sheet_cust_facing2.py", "sheet_changelist.py"]

# The labels that live in the middle of a line.
INLINE_LABELS = ["value", "name"]

for name in FILES:
    path = os.path.join(HERE, name)
    text = io.open(path, encoding="utf-8").read()
    count = 0
    for label in INLINE_LABELS:
        pattern = re.compile(
            r'IT COMMON - Get Cli Field(\s+)\$\{(\w+)\}(\s+)%s' % label
        )
        text, hits = pattern.subn(
            r'IT COMMON - Get Inline Field\1${\2}\3%s' % label, text
        )
        count += hits
        pattern = re.compile(
            r'IT COMMON - Cli Number Should Equal(\s+)\$\{(\w+)\}(\s+)%s(\s+)' % label
        )
        text, hits = pattern.subn(
            r'IT COMMON - Cli Inline Number Should Equal\1${\2}\3%s\4' % label, text
        )
        count += hits
    if count:
        io.open(path, "w", encoding="utf-8").write(text)
    print("%s: %d reads switched to the inline read" % (name, count))
print("done")
