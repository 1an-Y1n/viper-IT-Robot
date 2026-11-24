# Robot_Viper

Robot Framework test automation for the Viper LE DUT, driven by the LE
integration test template `Viper_LE-CAMP-00.04.006_IT_20261111.xlsx`
(Jira DZ300-1757).

## Layout

| Path | What it holds |
|------|---------------|
| `IT/` | The test suites, one folder per test item, one file per item. `IT/_generator/` writes the suites that are generated |
| `resource/Common/IT_Common.resource` | The keywords the suites share: the CLI, the gNMI and the gRPC calls, the waiting helpers |
| `lib/` | The Python libraries: `lib/Viper/` for the SSH / gNMI / gRPC access to the DUT, `lib/AutomationFlow.py` for the result bookkeeping |
| `variables/` | **The values of this testbed.** `variables/dut_variables.robot` holds the address of the DUT, `variables/env_variables.robot` the paths, `variables/fw_variables.robot` the firmware of the campaign. The templates live in `variables/sample/` |
| `images/` | The firmware of the campaign: the new release and the one before it. The images themselves are on the firmware server, see `images/README.md` |
| `result/` | The output of the runs. Every run gets its own folder, see below |
| `AGENT.md` | The working procedure: the order of the work, the generator, the traps, what may not be done |
| `IT_PROGRESS.md` | Which test item is done, what was measured on the DUT, what is still open |
| `IT_CONVENTIONS.md` | The rules the suites follow, and the Robot Framework traps that bite in this project |
| `IT_DUT_REFERENCE.md` | What the DUT really answers, read off the bench |

## Bootstrap

```bash
uv venv --python 3.12
uv pip install -r requirements.txt
cp variables/sample/dut_variables.robot variables/
cp variables/sample/env_variables.robot variables/
```

Then fill in the DUT's management address and serial number in
`variables/dut_variables.robot`, and the firmware of the campaign in
`variables/fw_variables.robot`. `requirements.txt` pins the versions this
project is known to run on.
The management address may be an IPv4 or IPv6 literal; write IPv6 without
brackets (and include a zone identifier for a link-local address). The runner
checks the address with `ping` before starting. Its Paramiko SSH client omits
the ML-KEM and sntrup hybrid key exchanges from its initial proposal to keep
the KEXINIT packet compatible with older DUT SSH servers.

## VS Code and Copilot

Open `robot_viper` as the VS Code workspace. The workspace recommends the
[RobotCode extension](https://marketplace.visualstudio.com/items?itemName=d-biehl.robotcode),
selects the existing `.venv`, and enables RobotCode's bundled Copilot Chat
plugin. That plugin provides RobotCode CLI guidance for discovering,
analyzing, running, and inspecting Robot Framework tests.

For the same general Robot Framework skills and validation hooks as Claude's
`rf-core` plugin, configure these **user** settings in VS Code:

```json
{
  "chat.plugins.enabled": true,
  "chat.useHooks": true,
  "chat.plugins.marketplaces": [
    "MarketSquare/robotframework-plugins#stable"
  ]
}
```

Then open **Chat: Open Customizations**, browse the Robot Framework plugins
marketplace, and install `rf-core`. Review and approve its hooks when VS Code
asks; they run RobotCode checks after relevant agent actions. The project
already has RobotCode 2.8.0 and Robocop in `.venv`, which meet the plugin's
CLI requirements. The plugin marketplace is a user-level setting and must be
added in each VS Code profile; `rf-core` does not install automatically with
the RobotCode extension. Project-specific Copilot guidance is in
`.github/copilot-instructions.md`.

The local Copilot hook configuration at the enclosing repository's
`.github/hooks/robot-viper.json` reuses the installed Claude `rf-core` 1.0.0
scripts for edit-time validation and the end-of-turn recheck, limited to this
project. It requires Node.js and the project `.venv`; restart the Copilot
session and approve workspace hooks if prompted. It does not install the
`rf-core` skills or the other plugin hooks. Remove this standalone hook before
enabling the plugin's own hooks to avoid duplicate checks. The configuration
and this project are ignored by the enclosing Git repository and remain local.

## Run

The whole campaign is one command. It runs the environment check first and
the test items after it, and it gives the run its own folder under `result/`:

```bash
./run_it.sh
```

ALN-007 is skipped: its RLSP measurement requires manual intervention after
calibration, and the suite does not currently pause for that measurement.
The environment check uploads firmware images to the firmware server. Some IT
tests also change DUT configuration, reboot it, or upgrade firmware; prepare
the bench before running the whole campaign.

Every argument goes to Robot, so the usual options work as well:

```bash
./run_it.sh -e BENCH          # without the cases that need the bench
./run_it.sh --suite PAB-016   # only the suites that match
```

Without the script, the same run is:

```bash
.venv/bin/robotcode robot --variable VERSION:run_20261119_1532 -d result/run_20261119_1532 IT_ENV IT
```

`IT_ENV` is the environment check, `IT` the test items of the template. The
check has to come first: it puts the images of the campaign on the firmware
server, which the upgrade items need.

One suite of one test item:

```bash
.venv/bin/robotcode robot --variable VERSION:run_20261119_1532 -d result/run_20261119_1532 IT/PAB/PAB-016
```

A run that leaves out the cases that need the bench:

```bash
.venv/bin/robotcode robot --variable VERSION:run_20261119_1532 -d result/run_20261119_1532 -e BENCH IT
```

The suites drive the DUT over its own management SSH. The gNMI and the gRPC
servers listen on the loopback of the DUT and `gnmic` / `grpcurl` run on the
DUT as well, so no second host is needed. `IT/README.md` has the details.
