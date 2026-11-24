# IT suite conventions (DZ300-1757)

These are the rules the IT suites under `IT/` follow. They exist because the
suites are generated from a test template and have to stay readable and
consistent with the rest of the project.

## Layout

```
IT/
  __init_resource.robot          what every IT suite imports
  <SHEET>/
    __init_resource.robot        what the suites of this sheet import
    <ID>/
      #<ID>.robot                the suite of that one test item
```

One folder per test item, one file per test item, the file named `#<ID>.robot`.
The `#` prefix keeps the file ahead of the other files of the folder in a
directory listing (`IT/PAB/PAB-016/#PAB-016.robot`).

A suite imports its sheet's `__init_resource.robot` with
`Resource    ../__init_resource.robot`, because the suite sits one level below
the sheet folder.

## File header

Every suite carries the header block right under `*** Settings ***`:

```robotframework
*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: what this suite checks
Documentation    <Sheet> | <area>
...              one or two lines on what the case does
Resource    ../__init_resource.robot
```

`*** Variables ***` and `*** Test Cases ***` follow, then `*** Keywords ***`.

## Test case naming

`[<ID>-<n>]<what the step does>`, for example `[PAB-001-1]Preset the PAB
configuration`. The number is the step order inside the test item, so a reader
can follow the template's procedure step by step.

Every test case carries `[Tags]`. The first tag is the sheet name (`PAB`,
`ALIGNMENT`, `ASC`, `CUST_FACING`, `CHANGELIST`), then the area (`CLI`,
`GNMI`, `GRPC`, `FILE`), then `WRITE` when the case changes the state of the
DUT.

## Variables

Use `VAR`, never `Set Variable`, and declare the log names at the start of the
test case:

```robotframework
    VAR    ${sc_log}    ${case_name}-1_sc_cli.log
```

`${case_name}` comes from the suite variables
(`${SUITE NAME.rsplit('#')[-1]}`) and is the test item id, so the log file of a
case is named after the item it belongs to.

## Assertions: no regexes in the suites

Robot Framework processes escape sequences in every string literal, and an
unknown escape loses its backslash. `"\s"` becomes `"s"` and `"\t"` becomes a
real tab, so a regex written straight into a test file breaks in a way that is
invisible until it silently matches the wrong thing.

So the suites never write a regex. They use the shared keywords of
`resource/Common/IT_Common.resource` instead:

| What is checked | Keyword |
| --- | --- |
| a labelled field of a command output | `IT COMMON - Get Cli Field`, `IT COMMON - Cli Field Should Equal` |
| a labelled field, with a fallback when absent | `IT COMMON - Get Cli Field Or Default` |
| a plain substring of a command output | `IT COMMON - Dut Command Should Contain` |
| a command that reported success | `IT COMMON - Dut Command Should Succeed` |
| a state change to land | `IT COMMON - Wait For Dut Cli Field`, `IT COMMON - Wait For Dut Cli Fields`, `IT COMMON - Wait For Dut Command Contains` |
| a leaf of a gNMI path | `IT COMMON - Gnmi Get Leaf Value`, `IT COMMON - Gnmi Leaves Should Exist` |
| a field of a gRPC answer | `IT COMMON - Grpc Get Field`, `IT COMMON - Grpc Get Nested`, `IT COMMON - Grpc Should Succeed` |

If a regex really is unavoidable, use character classes only (`[ ]*` for
blanks, `[0-9]+` for digits) or double the backslash (`\\s` reaches Python as
`\s`).

## The four Robot Framework traps

All of them cost a whole run of the suites before they were found, so they
are written down here.

### A variable of a test case is not visible in the keywords it calls

`VAR    ${x}    value` makes a **local** variable of the test case, and a
keyword that the test calls does not see it. The scope has to be named:

```robotframework
    VAR    ${x}    value                  # local: the keyword never sees it
    VAR    ${x}    value    scope=TEST    # test scope: the keyword sees it
```

This is why the log file of a test case is declared with `scope=TEST`: the
common keywords read `${sc_log}` as the name of the log file of the case that
is running, and a keyword only sees a variable of the test scope.

The call site of a keyword sees the local variable either way, so a value
that is passed to a keyword as an argument does not need the scope.

### A condition is Python, not Robot

An `IF` condition is evaluated as a Python expression, so:

| Wrong | Right | Why |
| --- | --- | --- |
| `IF    ${field} NOT IN @{data}` | `IF    $field not in $data` | `NOT IN` is not a Python operator, and `${field}` is put into the expression as text |
| `IF    ${update}[Path] == ${path}` | `IF    $update['Path'] == $path` | `${path}` is put into the expression as text, so a path like `pab-result/stage-1` is read as a division |
| `IF    "${value}" != "${expected}"` | keep it | the quotes are what make it safe |

`$name` hands the value over as an object, `${name}` hands it over as text.
The bare `$` form is the one to use in a condition.

### A variable is not a list just because it has commas

`VAR    ${x}    a, b, c` makes the **string** `a, b, c`, and
`VAR    ${x}    a    b    c` makes the string `a b c`. A list needs the `@`
sigil:

```robotframework
    VAR    @{names}    stage-1    stage-2    stage-3
    VAR    &{config}    key=value    other=thing
```

The `*** Variables ***` table does not know the `VAR` syntax at all, so there
the sigil of the name carries the kind of the variable:

```robotframework
*** Variables ***
@{names}    stage-1    stage-2    stage-3
&{config}    key=value    other=thing
```

### A bare variable is never the value of an assignment

`${x}=    ${y}` is **not** an assignment in Robot Framework 7.4.2, not even
when `${y}` is an ordinary variable. Robot Framework reads the cell as a call
of a keyword without a name and answers `Keyword name cannot be empty.`,
which is a long way from the real cause. The same goes for `${NONE}` and
`${EMPTY}`, the two built-ins that are easy to hit by accident.

```robotframework
    ${value}=    ${other}                     # wrong
    ${value}=    Set Variable    ${other}     # right
    ${value}=    ${NONE}                      # wrong
    VAR    ${value}    ${NONE}                 # right
```

The value of an assignment has to be a literal, a list, a dictionary, or the
result of a keyword call. A variable that holds nothing is written with `VAR`,
or it is not written at all.

A value that comes out of a loop survives the loop in 7.4.2, so a keyword can
keep the last answer it saw and put it into its failure message.

## The cases that need the bench

A suite that reboots the DUT, changes the firmware, wipes the configuration or
takes the management connection away carries the `BENCH` tag, so that a run on
a shared bench can leave it out:

```bash
.venv/bin/robotcode robot -e BENCH IT
```

`IT/README.md` lists the eighteen suites that carry it and says why.

## Talking to the DUT

| Session | Keyword | What runs there |
| --- | --- | --- |
| linux shell | `IT COMMON - Run Dut Command And Return` | `sc_cli`, `sc_rfboard_cli`, `sc_amphal_cli`, `sc_msc_cli` |
| clish | `IT COMMON - Run Fdx Command And Return` | the clish command tree |
| exec channel | `IT COMMON - Run Dut Exec Command And Return` | `gnmic` and `grpcurl` against the DUT's own loopback servers |

The gNMI and gRPC servers listen on the DUT's loopback, and `gnmic` / `grpcurl`
run on the DUT as well, so the target address is always `127.0.0.1`.

Three things about the exec channel are worth knowing, because a suite that
writes a gNMI call by hand has to follow them:

- **A long command does not fit.** The login shell of the DUT is clish, and it
  hands a non interactive command over to `sh` with a fixed buffer: 225
  characters still work, 226 are cut. `IT COMMON - Run Dut Exec Command And
  Return` sends a command that is too long over the ROOT session instead, so a
  suite does not have to care.
- **A refused request says so on stderr, and the exit status is 0.** The
  keyword merges the two streams, so the error text of a negative case is
  visible to the assertion.
- **A command with double quotes of its own does not fit either.** clish wraps
  the command in `sh -c "..."`, so the quotes of a JSON payload end the
  wrapper and the shell hands a broken JSON to the program. The gRPC calls
  carry a JSON payload, so they go over the ROOT session
  (`IT COMMON - Run Dut Root Command And Return`), which is a real bash.

## Where the logs go

The raw traffic of every command is written into a log file of its own, one
file per test case:

```
${RESULT_ROOT_PATH}/<suite>/<case>-<n>_<what>.log
```

`${RESULT_ROOT_PATH}` is `result/${VERSION}` (`variables/env_variables.robot`),
and `${VERSION}` can be set on the command line. The name of the file comes
from `${sc_log}`, which every test case declares with `scope=TEST`, so the
common keywords write into the log of the case that is running.

The logs are **appended**, so two runs of the same suite end up in the same
file. A run that has to be kept therefore gets a folder of its own, and the
same name for the version and for the output directory keeps everything of
that run together:

```bash
.venv/bin/robotcode robot --variable VERSION:run_20261119_1059 -d result/run_20261119_1059 IT
```

```
result/run_20261119_1059/
  output.xml  log.html  report.html      <- the report of that run
  PAB-002/PAB-002-1_gnmi.log              <- the commands of that one case
```

## Suite setup and teardown

The pattern is the one of `IT/PAB/PAB-001/#PAB-001.robot`: a `Suite Setup`
that opens the three sessions, and a `Suite Teardown` that closes them. The
suite variables carry the case name, and `Suite Initialization` / `Suite
Teardown` are the keyword names the project already uses.

## What the suites must not do

- No raw `ssh`. The DUT is reached through the `SSH_IT*` / `GNMI_IT` libraries.
- No `sleep` where a wait on a state change works: a wait has a timeout and a
  message that says what was being waited for.
- No test that depends on the order of another test item. Each suite sets up
  the state it needs and, where it changes the DUT, puts back what it changed.
