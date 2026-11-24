# The IT suites of the LE integration test template

These suites are the Robot Framework automation of the spreadsheet
`Viper_LE-CAMP-00.04.006_IT_20261111.xlsx` (Jira DZ300-1757). Every test
item of the five sheets that carry one is a suite of its own.

## What is here

```
IT/
  __init_resource.robot          what every IT suite imports
  _generator/                    the generator that writes the suites
  PAB/          16 items          PAB-001 .. PAB-016
  ALIGNMENT/    15 items          ALN-001 .. ALN-015
  ASC/          34 items          ASC-001 .. ASC-039, without five bench items
  CUST_FACING/  60 items          CF-001 .. CF-061
  CHANGELIST/   14 items          the items of the sheet that carry a procedure
```

The number of test cases changes as the items are reviewed.

The environment check sits beside `IT/`, not inside it: `IT_ENV/IT-ENV-001`.
It is not a test item of the template, and the campaign runs it before the
items, so it may not be part of `IT`.

## The environment check

`IT_ENV/IT-ENV-001` is not a test item of the template. It runs before the
campaign and tells whether the bench can carry it:

| Check | What it looks at |
| --- | --- |
| the images are in the local directory | the two images of the campaign are in `images/` |
| the images are on the firmware server | they are uploaded there with a PUT to the URL the DUT asks for, and the DUT finds them with the request the AMP makes itself |
| the DUT is the unit of the campaign | the serial number, over gNMI |
| the DUT reports its firmware version | the version the campaign ran against |
| the DUT reaches the firmware server | a ping from the DUT |

The upload happens in the second check, so the campaign puts the images on
the server by itself: run the environment check first and the DUT finds them
when the upgrade items run.

```bash
.venv/bin/robotcode robot --variable VERSION:run_20261119_1532 -d result/run_20261119_1532 IT_ENV
```

## Running them

The DUT is the bench unit `172.21.48.233` (serial `SCMLSA26200016`, firmware
`00.04.006`). The address is in `variables/dut_variables.robot`.

The bench has more than one unit and the address of a unit is not a fixed
property of it, so a suite that wants to know which unit it is talking to
reads the serial number of the DUT and compares it with `${DUT_IT_SERIAL}`.

```bash
cd dz1757_autotest/robot_viper
.venv/bin/robotcode robot IT
```

A run that leaves out the cases that need the bench:

```bash
.venv/bin/robotcode robot -e BENCH IT
```

The suites drive the DUT over its own management SSH. The gNMI and the gRPC
servers listen on the loopback of the DUT and `gnmic` / `grpcurl` run on the
DUT as well, so no second host is needed.

## The cases that need the bench

Eighteen suites carry the `BENCH` tag, because they cannot run on a shared
bench without preparation:

| Suite | Why it needs the bench |
| --- | --- |
| CF-004 | `sc_cli factory_default` wipes the configuration of the DUT |
| CF-006 | the syslog backup only shows up after a reboot |
| CF-015 | the configuration is compared over a reboot |
| CF-021 | `mgmtip` drops the management connection |
| CF-023, CF-024, CF-025, CF-051 | a firmware upgrade or a downgrade |
| CF-052 | a reset hard over gNMI |
| CF-058 | the SSH authentication settings can lock the bench out |
| ALN-002, ALN-003, ALN-004 | the full alignment flows, they reconfigure the DUT and reboot it |
| ALN-007 | `calib_us_legacy` and a write into `/mnt/sc_factory` |
| ALN-008, ALN-014 | the full calibration, it needs a signal source |
| ASC-010, ASC-011 | they clear the calibration snapshot of the DUT |

## The items with a step that is done on the bench

These items are automated, but one step of them is an action on the bench
that the suite cannot do. The suite automates the rest.

| Items | The step that is done on the bench |
| --- | --- |
| PAB-016 | `restore factory config` restores the factory default and **reboots the DUT on its own**. Wait for the unit to come back, then run the suite: it checks the state that comes out of the restore |
| CF-021, CF-023, CF-024, CF-025, CF-051, CF-052 | the step that needs the bench is a documented prerequisite, the suite automates the rest |

## The items that are not automated

| Items | Why |
| --- | --- |
| ALN-005, ALN-006 | they need the physical bench |
| ASC-012, ASC-014, ASC-022, ASC-024, ASC-025 | they need the physical bench |
| ASC-004, ASC-005, ASC-013 | scripts have external signal-control interfaces but are skipped until a bench adapter is available |
| the 16 items of CHANGELIST without a procedure | the template marks them as "no IT testing is required" or leaves them empty |
| CF-026, CF-027, CF-028 | the ICS button is a physical one; the suite reads the state of the RF board after the button was pressed |
| CF-033 | the LED state machine is watched by eye |

## What the suites found on the bench

The probes of the bench DUT turned up three things that the suites have to
take into account:

- **The ASC is gated by the calibration required flag.** As long as
  `sc_cli get_calib_req_config_flag` reads `true`, the four state machines
  report `enabled = false` and `sc_cli get_adu_status` reads `ON_HOLD`. The
  flag has to be cleared with `sc_cli set_calib_req_config_flag false` before
  the loops run at all.
- **The sc_cli commands do not all report success the same way.**
  `sc_cli set_asc_config` prints nothing, `sc_cli set_agc_config` prints
  `set_agc_config...success` and `sc_cli set_agc_control` prints
  `set_agc_control success` or `set_agc_control failed (1)` when the ASC is
  disabled.
- **The eCM reports two different states.** `sc_amphal_cli get_ecm_status`
  reads `eCM status = Operational` while the modem is up, but on the bench unit
  it stays at `RangeStart`, while `sc_cli get_snmp_cm_status` reads
  `eCM is OPERATIONAL`. The suites assert what the template asks for and
  report the difference.

## The gNMI and the gRPC calls

`gnmic` and `grpcurl` run on the DUT, against the loopback of the DUT. Four
things about that cost a lot of time until they were measured:

- **A SET needs the `--update` flag.** Without it gnmic refuses the request
  with `Error: no paths or request file provided` and nothing reaches the
  DUT.
- **A refused request is reported on stderr, and gnmic still exits with 0.**
  The exit status says nothing, so the error text is the only evidence and
  the calls merge the two streams.
- **The login shell of the DUT cuts a long command.** A command of 225
  characters still works, one of 226 characters is cut and the shell answers
  `sh: -c: line 0: unexpected EOF while looking for matching '"'`. The ROOT
  session is a real bash and takes the whole line, so a long command is sent
  there.
- **The paths of an answer are not the paths of the request.** gnmic writes
  them without the leading slash and holds the values under the path without
  its key selectors, so `lib/Viper/GnmiPath.py` does the lookup.

`../IT_DUT_REFERENCE.md` holds the details and the list of the things this
firmware does not have.

## What this image does not have

These were measured on the DUT of this bench, image 00.04.006. A suite that
needs one of them reports it, the deviation is not worked around.

| What | What the DUT answers |
| --- | --- |
| `GET /rf-components/us-fdx-input-attenuation-db` | `NotFound`, the leaf is a map over the port, so it has to be asked for with its port |
| `GET /wbfft-capture` | `NotFound`, the tree has no wbfft data at all, the feature `wbfft-capture-v1` is only advertised in the capabilities |
| `GET /amp-alignment` | `NotFound`, the stage has to be asked for with its type |
| `SET /spectrum-allocation/...` | `internal set failed: Invalid input param` |
| `SET /ds-profile/.../data-set-name` | `internal set failed: Invalid input param` |
| `SET /amp-identification/device-location/...` | `internal set failed: Invalid input param` |
| `SET /software-upgrade/update-type` | `SetRequest not valid` |
| `SET /rf-components/north-port-switch-path` | `failed RfiPalCfg::setNorthPortSwitch` |
| the Broadcom CLI wrappers (`debug hal`, `cliwrapper_client`) | they connect (`Trying to connect... Connected. Press Ctrl-D to exit`) but never print their prompt (`hal>`, `brcmsystem>`, `brcmupgrade>`) |
| `/mnt/sc_nonvol/asc_calib_snapshot.json` | never written, the store needs a full calibration |
| `Dstracker` | not deployed, the gRPC call answers "Dstracker is not ready." |
| the SSH user table | 32 users, the suite that creates a user needs them to be removed first |

The two documents next to this one hold the details:
`../IT_CONVENTIONS.md` the rules the suites follow and `../IT_DUT_REFERENCE.md`
what the DUT really answers, read off the bench.


## The generator

The suites are written by `IT/_generator/`, one module per sheet. The
generator owns the boilerplate (the header block, the suite variables, the
suite setup and teardown); what each suite asserts is written by hand in the
spec modules, against the output that `IT_DUT_REFERENCE.md` records.

```bash
python3 IT/_generator/build.py            # every sheet
python3 IT/_generator/build.py PAB ASC    # two sheets
```

`IT/PAB/PAB-001` was written by hand and is not covered by the generator.
