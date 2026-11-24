"""Write the IT suites of every sheet from their specs.

    python3 IT/_generator/build.py [sheet ...]

Without a sheet argument every sheet is written. The suites that were written
by hand (IT/PAB/PAB-001) are not touched: no spec module covers them.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IT_ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import writer  # noqa: E402

SHEETS = [
    ("PAB", "sheet_pab"),
    ("ALIGNMENT", "sheet_alignment"),
    ("ASC", "sheet_asc"),
    ("CUST_FACING", "sheet_cust_facing"),
    ("CUST_FACING", "sheet_cust_facing2"),
    ("CHANGELIST", "sheet_changelist"),
]


def main(argv):
    wanted = argv[1:] or [name for name, _ in SHEETS]
    written = []
    for sheet, module in SHEETS:
        if sheet not in wanted:
            continue
        __import__(module)
    for spec in writer.SUITES:
        folder = os.path.join(IT_ROOT, spec["sheet"])
        written.append(writer.write(folder, spec))
    for path in written:
        print(path)
    print("%d suites written" % len(written))


if __name__ == "__main__":
    main(sys.argv)
