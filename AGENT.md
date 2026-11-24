# Working on this project (DZ300-1757)

This file is the operating procedure for whoever picks the work up. It says
what the job is, in which order to do it, what may not be done, and where the
state of the work is written down. The reference documents next to it hold the
details and are linked from here, not repeated.

| Document | What it holds |
| --- | --- |
| **`IT_PROGRESS.md`** | **the state of the work**: which test item is reviewed, what was measured on the DUT, what is still open, what the open questions are |
| `IT_CONVENTIONS.md` | the rules the suites follow and the Robot Framework traps that bite in this project |
| `IT_DUT_REFERENCE.md` | what the DUT really answers, read off the bench |
| `robot_coding_style.md` | the style of the suites |
| `README.md`, `IT/README.md` | the layout, how to run the campaign |

---

## 1. What the job is

Turn **every test item of every sheet** of the LE integration test template
`Viper_LE-CAMP-00.04.006_IT_20261111.xlsx` (Jira **DZ300-1757**) into a
Robot Framework suite, and prove it on the bench DUT.

Three sources of truth, in this order:

1. **The template** is the specification: every item has a procedure and a list
   of expected results. The `.md` next to the `.xlsx` is the same table and is
   easier to grep.
2. **The User Guide** (extracted into `../../okf-bundle/chapters/`) is the
   authority behind the template. Every expectation of the template points at a
   chapter.
3. **The DUT is the final fact.** When the guide and the DUT disagree, the DUT
   wins and the difference is written down in `IT_PROGRESS.md`.

The source of the firmware is `../../meta-sercomm-internal/` — read it when the
guide and the DUT disagree, it says what a command really does.

## 2. The order of the work

**One test item at a time.** The user reviews every item before the next one
starts, and the review always has this shape:

1. **What the item is for and what it contains** — the purpose, the procedure
   of the template, the expectations.
2. **The test steps** — the commands as they are measured on the DUT, with the
   answers the DUT gives and how long they take.
3. **How the script is written and whether it passed** — the suite, what it
   asserts, the result of the run.

Do not start the next item before the user says so. **Ask when something is
unclear** — the template is written for a factory line, the bench is not, and
the difference is often the interesting part of the item.

### The steps of one item

1. **Read the row of the template.** `grep` the id in
   `../../Viper_LE-CAMP-00.04.006_IT_20261111.md`.
2. **Read the chapter of the User Guide** it points at.
3. **Read the source** when the guide is not specific enough.
4. **Probe the DUT** (section 4): measure the answer of every command, the
   timing, and the side effects on the state of the unit.
5. **Write the spec** of the suite in the generator module of the sheet
   (section 3), regenerate, and run it on the DUT.
6. **Tighten the assertions.** A suite that passes without proving anything is
   worse than no suite at all: every item that was reviewed so far had at least
   one assertion that was too loose (`Should Contain ... success` on a command
   that also prints `failed`, a status line that carries the name of the
   stage whatever the state of it is, a number compared as a string).
7. **Write the section in `IT_PROGRESS.md`** and update the table row of the
   item.
8. **Report to the user** in the shape 1 / 2 / 3 above, with the open questions
   at the end.

## 3. The generator: a suite is never edited by hand

The suites under `IT/<SHEET>/<ID>/#<ID>.robot` are **written by the
generator**. Hand edits are lost on the next build.

```
IT/_generator/
  writer.py            the boilerplate: the header, the suite variables, the
                       setup and the teardown; the API is S(...) and C(...)
  sheet_pab.py         the spec of the PAB items
  sheet_alignment.py   the spec of the ALIGNMENT items
  sheet_asc.py         ...
  build.py             writes the suites
```

```bash
python3 IT/_generator/build.py ALIGNMENT     # one sheet
python3 IT/_generator/build.py               # every sheet
```

A spec is a plain dict:

```python
S("ALN-008",
  bench=True,                    # the suite carries the BENCH tag
  sheet="ALIGNMENT",
  area=CLISH_CAL,
  comment="...",                 # the header of the suite
  doc="...",                     # the documentation of the suite
  cases=[
      C("Run the calibration in auto mode",
        doc=["Step 1. ...", "Step 2. ..."],
        tags=["CLI", "WRITE"],
        log="auto.log",          # the log file of the case
        body=["${start}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration auto    timeout=600",
              "Should Contain    ${start}    Result: SUCCESS"]),
  ])
```

Traps of the generator itself:

- **A `"\n"` inside a body string writes a real newline into the .robot file**
  and breaks it into bogus test cases. Use `" | "`.
- **The quotes of a Robot cell have to be escaped in the Python string**:
  `"IF    \"${x}\" == \"True\""`. The mistake breaks the Python file, and the
  repair is easy to get wrong — check `python3 -c "import ast; ast.parse(...)"`
  after every edit of a spec module.
- The writer owns the boilerplate. If a suite needs something the writer cannot
  express, extend the writer rather than the generated file.

## 4. Talking to the DUT

The suites drive the DUT over its own management SSH (`variables/dut_variables.robot`
holds the address). For the **manual probes** use the **viper-tether skill**,
never raw ssh.

> ⚠️ **The tether target and the suite target can be two different machines.**
> The suites use `${SSH_DUT_IT}` from `variables/dut_variables.robot`; the
> tether uses the environment variable `TETHER_DEVICE_HOST`, and its daemon
> keeps the target it was started with. **Always check which unit the tether
> is on** before a probe — `env` on the DUT prints `SSH_CONNECTION`, which
> carries the address — and address the unit explicitly when in doubt:
>
> ```bash
> cd ~/.claude/plugins/cache/viper-plugin/viper-skills/*/skills/viper-tether
> ./tether/tether --once amp_admin@172.21.48.233 "cat /proc/uptime"
> ```
>
> A conclusion that was measured on the wrong unit is worse than no conclusion.

The DUT has two shells: **clish** (`FDX-AMP>$`, the views
`FDX-AMP(calibration)>$` and so on) and the **linux shell** (`debug shell`,
the prompt `bash-3.2#`, where `sc_cli` / `sc_rfboard_cli` / `sc_amphal_cli`
and `gnmic` / `grpcurl` live).

### The state of the DUT belongs to the user

The bench unit is shared. After a run the unit has to be in the state it was
in before, and the state that a suite changes has to be put back:

| What a suite changes | How it is put back |
| --- | --- |
| `/mnt/sc_factory/ecm_rfb_offset` | the value it had is written back in the teardown of the suite |
| the nonvol values (`sc_cli set_max_ecm_tx_power` and the like) | **write them back by hand** — the value of the unit is a factory value, not something a test may keep |
| the JXP tilt (`sc_rfboard_cli set_legacy_up_jxp_tilt`) | the calibration writes it, so the case sets it back to 0 before it runs |
| the lineup (ds-profile, us-profile, spectrum) | the alignment suites leave the DUT in the lineup of the template on purpose — that is what the bench is for; **say so in the report** |

## 5. The checks before an item is done

```bash
# the whole tree parses and the keywords resolve
.venv/bin/robot --dryrun --outputdir /tmp/dryrun --output NONE --report NONE --log NONE IT_ENV IT
# 325 tests, 325 passed

# the static analysis
.venv/bin/robotcode analyze code
# Files: 151, Errors: 0, Warnings: 17, Infos: 0, Hints: 27
```

Both numbers are the baseline: a change that moves them is a change that has
to be explained.

One suite of one item, with its own result folder:

```bash
.venv/bin/robotcode robot --outputdir result/aln008_233b IT_ENV IT/ALIGNMENT/ALN-008
```

ALN-007 is skipped because it requires a manual RLSP measurement after
calibration, and the suite does not pause for that measurement. Supplying
`ALN007_MANUAL_DEVIATION` does not enable the skipped suite.

The whole campaign is `./run_it.sh` (it checks that the DUT answers before it
starts). The environment check `IT_ENV/IT-ENV-001` runs first and puts the
firmware of the campaign on the firmware server.

## 6. The traps of this project

The four Robot Framework traps are in `IT_CONVENTIONS.md`; the ones that cost
the most time here:

- **Robot eats the backslash of an escape it does not know.** `\s` in a cell
  becomes `s`, so a regex written straight into a suite silently matches the
  wrong thing. Use character classes (`[0-9]+`, `[.]`, `[ ]`) or double the
  backslash. **Every regex lives in `resource/Common/IT_Common.resource`.**
- **A value read with a regex that does not stop at the end of the line runs
  into the next line.** `IT COMMON - Get Inline Field` joins the lines with a
  blank before it reads.
- **A variable of a test case is not visible in the keywords it calls.** A
  keyword that needs a value of the case gets it as an argument.
- **`VAR ${x}= ${y}` is not valid.** Use `Set Variable`.

## 7. What may not be done

- **Do not build and do not deploy.** This is a **DZ300-** ticket: the user
  merges the work and triggers the compile. Do not run `viper-build` and do not
  put anything on the DUT with `viper-app-update`.
- **Do not push to Gerrit.** No `git push`, not even `%wip`, without the user
  saying so. The user reviews the local commit and pushes it.
- **One Jira task, one commit.** Do not split the work of a ticket over
  several commits, and do not commit the design notes — only the code.
- **Before a PR**: the files have to be LF and the chmod bits have to be
  right, and the `dos2unix` / `chmod -x` run has to touch **only the files
  that changed** (`git diff --name-only`), never the whole tree.
- The project `dz1757_autotest/robot_viper` is **not in git** — the deliverable
  of the ticket is elsewhere in `3_camp`.

## 8. Where the state of the work is written down

**`IT_PROGRESS.md`**, and nowhere else. It has a table of every item with its
state, and a section per reviewed item that follows the shape of the review:

```markdown
### ALN-008 — ALIGNMENT | CLISH Calibration Modes

在 `.233` 上跑完，**4/4 通过**（`result/aln008_233b`）。这一项原来是 3 条用例，
断言太松，这次重写成 4 条。

**这一项在做什么**：...

**4 条用例**：...

#### 实机结果（.233）

| 命令 | 结果 | 用时 |
| --- | --- | --- |

#### 三个跟模板/手册对不上的地方

1. ...

#### 改紧的断言

| 原来 | 现在 |
| --- | --- |
```

Update it **in the same change** as the suite: the table row of the item, the
section of the item, and — when something was found on the bench that the next
agent has to know — the note at the top of the file.
