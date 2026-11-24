"""Render one Robot Framework suite file per test item of the LE IT template.

The IT suites under IT/ are generated from the spreadsheet so that the shared
boilerplate (header block, suite variables, suite setup and teardown) is
written once and every suite looks the same. The generator only owns the
boilerplate: what each suite asserts comes from the spec modules next to
this file, which are written by hand against the DUT reference.

A spec is a plain dict. The two shorthands below are all that is needed:

    S("PAB-003", sheet="PAB", area="GNMI Result", comment="...", doc="...",
      vars=[("path", "pab-result/stage-1")],
      cases=[
          C("Read the stage 1 result", log="1_gnmi.log", tags=["GNMI"],
            doc=["Step 1. GET it", "Step 2. Check the leaves"],
            vars=[("leaves", ["message", "status"])],
            body=["${resp}=    IT COMMON - Gnmi Get And Return    ${path}"]),
      ])

A variable value is a string for a scalar, a list for a list variable and a
dict for a dictionary variable; the generator picks the Robot syntax.
"""

import json
import os

TEMPLATE = """*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: @COMMENT@
Documentation    @SHEET@ | @AREA@
...              @DOC@
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
@SUITE_VARS@
*** Test Cases ***
@CASES@
*** Keywords ***
Suite Initialization
    log to console  \\n\\t=== Suite Initialization START ===
    AutomationFlow.automation initial
    SSH_IT_ROOT.Connect    ssh_setting=${SSH_DUT_IT}    level=ROOT    main_log_name=${case_name}-ssh_root.log
    SSH_IT.Connect    ssh_setting=${SSH_DUT_IT}    level=FDX    main_log_name=${case_name}-ssh_fdx.log
    GNMI_IT.Connect    ssh_setting=${SSH_DUT_IT}    gnmi_setting=${GNMI_DUT_IT}    main_log_name=${case_name}-gnmi.log
    log to console  \\n\\t=== Suite Initialization STOP ===

Suite Teardown
    log to console  \\n\\t=== Suite Teardown START ===
@TEARDOWN@
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \\n\\t=== Suite Teardown STOP ===
"""

SUITES = []


def S(item_id, sheet, area, comment, doc, cases, vars=None, bench=False,
      teardown=None):
    """Register one suite.

    A suite that needs the bench carries the BENCH tag: it reboots the DUT,
    changes the firmware, wipes the configuration or takes the management
    connection away, so it cannot run on a shared bench without preparation.

    ``teardown`` is the body of the suite teardown of that one suite, e.g. the
    steps that put back a configuration the suite has changed. The teardown of
    a suite runs after all of its cases, and it runs even when a case failed,
    so it is the right place for the housekeeping.
    """
    spec = {
        "id": item_id,
        "sheet": sheet,
        "area": area,
        "comment": comment,
        "doc": doc,
        "cases": cases,
        "vars": vars or [],
        "bench": bench,
        "teardown": teardown or [],
    }
    SUITES.append(spec)
    return spec


def C(name, body, doc=None, tags=None, log=None, vars=None):
    """One test case of a suite."""
    return {
        "name": name,
        "body": body,
        "doc": doc or [],
        "tags": tags or [],
        "log": log,
        "vars": vars or [],
    }


def _dict_items(value):
    """The items of a dictionary variable.

    A value that is a list is written as JSON, because the dictionary syntax
    of Robot Framework carries strings only. The keyword that reads the
    dictionary parses the JSON back.
    """
    items = []
    for key in value:
        item = value[key]
        if isinstance(item, (list, tuple)):
            item = json.dumps(list(item))
        items.append("%s=%s" % (key, item))
    return items


def _var_line(name, value):
    """One VAR line for a value of any of the three Robot variable kinds."""
    if isinstance(value, dict):
        return "VAR    &{%s}    %s" % (name, "    ".join(_dict_items(value)))
    if isinstance(value, (list, tuple)):
        return "VAR    @{%s}    %s" % (name, "    ".join(str(item) for item in value))
    return "VAR    ${%s}    %s" % (name, value)


def _table_line(name, value):
    """One line of the *** Variables *** table.

    The table does not know the VAR syntax, so the kind of the variable is
    carried by the sigil of its name instead.
    """
    if isinstance(value, dict):
        return "&{%s}    %s" % (name, "    ".join(_dict_items(value)))
    if isinstance(value, (list, tuple)):
        return "@{%s}    %s" % (name, "    ".join(str(item) for item in value))
    return "${%s}    %s" % (name, value)


def render(spec):
    """Render one suite file out of its spec and return the text."""
    cases = []
    for number, case in enumerate(spec["cases"], start=1):
        lines = ["[%s-%d]%s" % (spec["id"], number, case["name"])]
        lines.append("    [Documentation]")
        for line in case["doc"]:
            lines.append("    ...              %s" % line)
        tags = list(case["tags"]) or [spec["sheet"]]
        if spec.get("bench") and "BENCH" not in tags:
            tags.append("BENCH")
        lines.append("    [Tags]    %s" % "    ".join(tags))
        if case["log"]:
            # scope=TEST, because the common keywords read ${sc_log} as the
            # name of the log file of the case. A VAR without a scope is a
            # local variable of the test case, and a keyword that is called
            # by the test does not see a local variable.
            lines.append(
                "    VAR    ${sc_log}    ${case_name}-%s    scope=TEST"
                % case["log"])
        for name, value in case["vars"]:
            lines.append("    " + _var_line(name, value))
        for line in case["body"]:
            lines.append("    %s" % line if line else "")
        cases.append("\n".join(lines))
    text = TEMPLATE
    text = text.replace("@COMMENT@", spec["comment"])
    text = text.replace("@SHEET@", spec["sheet"])
    text = text.replace("@AREA@", spec["area"])
    text = text.replace("@DOC@", spec["doc"])
    text = text.replace("@SUITE_VARS@", _suite_vars(spec))
    text = text.replace("@CASES@", "\n\n".join(cases))
    text = text.replace("@TEARDOWN@", _teardown(spec))
    return text


def _teardown(spec):
    """The body of the suite teardown of one suite."""
    if not spec["teardown"]:
        return "    # the suite has nothing to clean up"
    return "\n".join("    %s" % line if line else "" for line in spec["teardown"])


def _suite_vars(spec):
    if not spec["vars"]:
        return "# the suite carries no variable of its own"
    return "\n".join(_table_line(name, value) for name, value in spec["vars"])


def write(sheet_root, spec):
    """Write the suite file of one spec and return the path."""
    folder = os.path.join(sheet_root, spec["id"])
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, "#%s.robot" % spec["id"])
    with open(path, "w") as handle:
        handle.write(render(spec))
    return path
