import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

from robot import run
from robot.libraries.BuiltIn import BuiltIn

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "IT" / "_generator"))
import writer
import sheet_asc  # noqa: F401


def fake_asc009_command(command, timeout=15):
    case = next(spec for spec in writer.SUITES if spec["id"] == "ASC-009")["cases"][0]
    fields = dict(case["vars"])
    scenario = BuiltIn().get_variable_value("${scenario}")
    if command == "sc_cli get_agc_config":
        return "Fdx enable: " + ("false" if scenario == "empty-fdx-disabled" else "true")
    if command == "sc_cli asc_calib_snapshot show":
        lines = ["ds_end_frequency_hz : 1218000000 Hz"]
        lines.extend(f"{name} : 10.00 dBmV" for name in fields["tcp_fields"])
        lines.append("pilot_goertzel : 1 entries")
        lines.append("  165000000 Hz 10.00 dBmV")
        lines.extend(f"{name} 10.00 dB" for name in fields["state_fields"])
        lines.extend(
            f"{name} : {0 if name == 'fdx_path_gain_cal' and scenario.startswith('empty-fdx') else 3} bins"
            for name in fields["bin_fields"]
        )
        return "\n".join(lines)
    if command.startswith("sc_cli asc_calib_snapshot dump "):
        return f"1 bytes written to {command.split()[-1]}"
    raise AssertionError(f"Unexpected DUT command: {command}")


def fake_asc009_root(command, timeout=15):
    builtin = BuiltIn()
    scenario = builtin.get_variable_value("${scenario}")
    case = next(spec for spec in writer.SUITES if spec["id"] == "ASC-009")["cases"][0]
    fields = dict(case["vars"])
    if command.startswith("mktemp "):
        return "/tmp/it_asc009_test1234"
    if command.startswith("jq "):
        summary = {name: 10.0 for name in fields["tcp_fields"]}
        summary["calibration_state"] = {name: 10.0 for name in fields["state_fields"]}
        summary["pilot_goertzel"] = [{"freq": 165000000, "value": 10.0}]
        summary["counts"] = {name: 3 for name in fields["bin_fields"]}
        if scenario == "wrong-bin-count":
            summary["counts"]["pilot_wbfft"] = 2
        elif scenario == "missing-rf-state":
            del summary["calibration_state"][fields["state_fields"][0]]
        elif scenario == "wrong-pilot":
            summary["pilot_goertzel"][0]["value"] = 11.0
        elif scenario.startswith("empty-fdx"):
            summary["counts"]["fdx_path_gain_cal"] = 0
        return json.dumps(summary)
    if command.startswith("rm -f -- "):
        builtin.set_suite_variable("${cleaned}", True)
        return "REMOVED"
    raise AssertionError(f"Unexpected root command: {command}")


def fake_restore_command(command):
    builtin = BuiltIn()
    state = builtin.get_variable_value("${state}")
    writes = builtin.get_variable_value("${writes}")
    if command == "sc_cli get_asc_config":
        return "\n".join(f"{key} = {value}" for key, value in state.items())
    prefix, key, value = command.rsplit(" ", 2)
    if prefix != "sc_cli set_asc_config":
        raise AssertionError(f"Unexpected command: {command}")
    writes.append(key)
    if key == "inputPowerTransientThreshold" and builtin.get_variable_value("${scenario}") == "set-fails":
        builtin.fail("Simulated restore failure")
    state[key] = {"0": "Disable", "1": "FreeRun", "2": "Monitor"}[value] if key == "operationMode" else value
    return ""


def fake_np_ds_status(command):
    if command != "sc_cli get_asc_fsm_status np_ds":
        raise AssertionError(f"Unexpected command: {command}")
    scenario = BuiltIn().get_variable_value("${scenario}")
    enabled = "false" if scenario == "disabled" else "true"
    stage = "Idle" if scenario in ("idle", "disabled") else "Measure"
    return f"enabled : {enabled}\ncurrent_stage : {stage}\nloop_count : 0"


def fake_boot_id(command):
    if command != "cat /proc/sys/kernel/random/boot_id":
        raise AssertionError(f"Unexpected command: {command}")
    builtin = BuiltIn()
    calls = builtin.get_variable_value("${calls}")
    if builtin.get_variable_value("${scenario}") == "rebooted" and calls >= 2:
        return "22222222-2222-2222-2222-222222222222"
    return "11111111-1111-1111-1111-111111111111"


def fake_persisted_config(path, timeout=5, poll=1):
    scenario = BuiltIn().get_variable_value("${scenario}")
    config = {
        "public_config": {
            "operation_mode": 1,
            "input_interval": 300,
            "input_power_transient_threshold": 0.2,
        },
        "private_config": {
            "fdx_us_att_threshold": 0.5,
            "fdx_us_eq_threshold": 0.5,
            "rfboard_notify_interval": 3600,
        },
    }
    if scenario == "wrong-eq":
        config["private_config"]["fdx_us_eq_threshold"] = 0.3
    elif scenario == "missing-notify":
        del config["private_config"]["rfboard_notify_interval"]
    elif scenario == "wrong-mode":
        config["public_config"]["operation_mode"] = 0
    return config


def fake_persisted_write(command):
    builtin = BuiltIn()
    writes = builtin.get_variable_value("${writes}")
    writes.append(command)
    if "set_agc_config 1 " in command and builtin.get_variable_value("${scenario}") == "set-fails":
        builtin.fail("Simulated AGC write failure")
    return "set_agc_config...success"


def fake_telemetry_config(path, timeout=5, poll=1):
    scenario = BuiltIn().get_variable_value("${scenario}")
    return {"private_config": {"telemetry_persist_interval": 86400 if scenario == "stale-file" else 60}}


def fake_fsm_states(command):
    scenario = BuiltIn().get_variable_value("${scenario}")
    fsm = command.rsplit(" ", 1)[-1]
    enabled = "true" if scenario == "one-enabled" and fsm == "sp_ds" else "false"
    stage = "Measure" if scenario == "one-running" and fsm == "np_us" else "Idle"
    return f"enabled : {enabled}\ncurrent_stage : {stage}"


def fake_grpc_asc():
    scenario = BuiltIn().get_variable_value("${scenario}")
    expected = BuiltIn().get_variable_value("${expected}")
    config = dict(expected)
    if scenario == "wrong-grpc":
        config["outputInterval"] = 900
    elif scenario == "missing-enable":
        del config["enable"]
    return {"success": {"status": "SUCCESS"}, "ascConfig": config}


def fake_cli_asc(command):
    scenario = BuiltIn().get_variable_value("${scenario}")
    expected = BuiltIn().get_variable_value("${expected}")
    lines = ["operationMode = FreeRun"]
    for key, value in expected.items():
        if key != "enable":
            lines.append(f"{key} = {900 if scenario == 'wrong-cli' and key == 'outputInterval' else value}")
    return "\n".join(lines)


def fake_asc038_grpc(proto, method, data=""):
    builtin = BuiltIn()
    writes = builtin.get_variable_value("${writes}")
    original = {"enable": 1, "inputInterval": 120}
    if method.endswith("/GetAscConfiguration"):
        return {"success": {"status": "SUCCESS"}, "ascConfig": original}
    if method.endswith("/SetAscConfiguration"):
        writes.append(json.loads(data))
        if len(writes) == 1 and builtin.get_variable_value("${scenario}") == "set-fails":
            return {"success": {"status": "FAILURE"}}
        return {"success": {"status": "SUCCESS"}}
    raise AssertionError(f"Unexpected method: {method}")


def fake_asc030_command(command):
    builtin = BuiltIn()
    state = builtin.get_variable_value("${state}")
    if command == "sc_cli get_asc_config":
        return f"operationMode = {state['mode']}"
    if command == "sc_cli get_asc_fsm_status np_ds":
        state["reads"] += 1
        count = 2 if state["reads"] == 2 and builtin.get_variable_value("${scenario}") == "accumulates" else 1
        return f"loop_count : {count}"
    if command == "sc_cli set_asc_config operationMode 0":
        state["mode"] = "Disable"
        state["disabled"] = True
        return ""
    raise AssertionError(f"Unexpected command: {command}")


class AscSequenceTest(unittest.TestCase):
    def test_fsm_count_failure_still_checks_disable_and_restores_mode(self):
        case = next(spec for spec in writer.SUITES if spec["id"] == "ASC-030")["cases"][0]
        for scenario in ("accumulates", "resets"):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "Suite Teardown    Check Restore",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "*** Test Cases ***",
                "Check FSM",
                "    VAR    ${state}    ${{{'mode': 'FreeRun', 'reads': 0, 'disabled': False}}}    scope=SUITE",
                *("    " + writer._var_line(name, value) for name, value in case["vars"]),
                *("    " + line for line in case["body"]),
                "*** Keywords ***",
                "IT COMMON - Run Dut Command And Return",
                "    [Arguments]    ${command}",
                "    ${out}=    Fake.Fake Asc030 Command    ${command}",
                "    RETURN    ${out}",
                "IT ASC - FSM Status Should Be Valid",
                "    [Arguments]    @{args}",
                "    No Operation",
                "IT ASC - All FSMs Should Have State",
                "    [Arguments]    @{args}",
                "    No Operation",
                "IT ASC - NP DS Should Be Idle",
                "    No Operation",
                "IT ASC - NP DS Should Be Running",
                "    RETURN    current_stage : Measure",
                "IT ASC - Restore Operation Mode",
                "    [Arguments]    ${mode}",
                "    Set To Dictionary    ${state}    mode=${mode}",
                "Check Restore",
                "    Should Be True    $state['disabled']",
                "    Should Be Equal    ${state}[mode]    FreeRun",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "asc030.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "accumulates", output.getvalue())
                self.assertNotIn("Suite teardown failed", output.getvalue())

    def test_grpc_restore_runs_after_set_failure(self):
        case = next(spec for spec in writer.SUITES if spec["id"] == "ASC-038")["cases"][0]
        for scenario in ("valid", "set-fails"):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "Suite Teardown    Check Restore",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "${proto}    asc_config.proto",
                "${get_method}    gnoi.asc_config.v1.AscConfigService/GetAscConfiguration",
                "${set_method}    gnoi.asc_config.v1.AscConfigService/SetAscConfiguration",
                "*** Test Cases ***",
                "Set config",
                "    VAR    @{writes}    scope=SUITE",
                *("    " + writer._var_line(name, value) for name, value in case["vars"]),
                *("    " + line for line in case["body"]),
                "*** Keywords ***",
                "IT COMMON - Grpcurl And Return Json",
                "    [Arguments]    ${proto}    ${method}    ${data}=${EMPTY}",
                "    ${out}=    Fake.Fake Asc038 Grpc    ${proto}    ${method}    ${data}",
                "    RETURN    ${out}",
                "IT ASC - Grpc And CLI Configuration Should Equal",
                "    [Arguments]    ${expected}",
                "    No Operation",
                "Check Restore",
                "    Length Should Be    ${writes}    2",
                "    Should Be Equal    ${writes}[1][ascConfig]    ${{{'enable': 1, 'inputInterval': 120}}}",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "asc038-restore.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "valid", output.getvalue())
                self.assertNotIn("Suite teardown failed", output.getvalue())

    def test_grpc_and_cli_compare_every_configuration_field(self):
        config = {
            "enable": 1, "inputInterval": 120, "outputInterval": 600,
            "clippingInterval": 1, "inputPowerTransientThreshold": 0.5,
            "deltaPilotDiffThreshold": 0.7, "maxPositiveAdjustment": 4,
            "maxNegativeAdjustment": -4, "firstPilotFrequency": 261000000,
            "secondPilotFrequency": 711000000, "thirdPilotFrequency": 903000000,
        }
        for scenario in ("valid", "wrong-grpc", "wrong-cli", "missing-enable"):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "*** Test Cases ***",
                "Check config",
                f"    VAR    ${{expected}}    ${{{{{config!r}}}}}    scope=TEST",
                "    IT ASC - Grpc And CLI Configuration Should Equal    ${expected}",
                "*** Keywords ***",
                "IT COMMON - Grpcurl And Return Json",
                "    [Arguments]    ${proto}    ${method}",
                "    ${out}=    Fake.Fake Grpc Asc",
                "    RETURN    ${out}",
                "IT COMMON - Run Dut Command And Return",
                "    [Arguments]    ${command}",
                "    ${out}=    Fake.Fake Cli Asc    ${command}",
                "    RETURN    ${out}",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "grpc-asc.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "valid", output.getvalue())

    def test_all_fsms_must_stop(self):
        for scenario in ("valid", "one-enabled", "one-running"):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "*** Test Cases ***",
                "Check all loops",
                "    IT ASC - All FSMs Should Have State    false    ${TRUE}",
                "*** Keywords ***",
                "IT COMMON - Run Dut Command And Return",
                "    [Arguments]    ${command}",
                "    ${out}=    Fake.Fake Fsm States    ${command}",
                "    RETURN    ${out}",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "all-fsms.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "valid", output.getvalue())

    def test_telemetry_interval_requires_live_and_saved_values(self):
        for scenario in ("valid", "stale-live", "stale-file"):
            live = 86400 if scenario == "stale-live" else 60
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "*** Test Cases ***",
                "Check interval",
                "    IT ASC - Telemetry Interval Should Equal    60",
                "*** Keywords ***",
                "IT COMMON - Run Dut Command And Return",
                "    [Arguments]    ${command}",
                f"    RETURN    Telemetry persist interval: {live}",
                "IT COMMON - Wait For Dut Json File",
                "    [Arguments]    ${path}    ${timeout}=5    ${poll}=1",
                "    ${out}=    Fake.Fake Telemetry Config    ${path}    ${timeout}    ${poll}",
                "    RETURN    ${out}",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "telemetry.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "valid", output.getvalue())

    def test_persisted_configuration_checks_all_sections(self):
        for scenario in ("valid", "wrong-eq", "missing-notify", "wrong-mode"):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "*** Test Cases ***",
                "Check saved values",
                "    IT ASC - Persisted Configuration Should Equal    FreeRun    300    0.2    0.5    0.5    3600",
                "*** Keywords ***",
                "IT COMMON - Wait For Dut Json File",
                "    [Arguments]    ${path}    ${timeout}=5    ${poll}=1",
                "    ${out}=    Fake.Fake Persisted Config    ${path}    ${timeout}    ${poll}",
                "    RETURN    ${out}",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "persisted.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "valid", output.getvalue())

    def test_persisted_restore_attempts_all_writes_after_failure(self):
        for scenario in ("valid", "set-fails"):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "Suite Teardown    Length Should Be    ${writes}    6",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "*** Test Cases ***",
                "Restore",
                "    VAR    @{writes}    scope=SUITE",
                "    IT ASC - Set And Verify Persisted Configuration    FreeRun    120    0.5    0.3    0.3    86400",
                "*** Keywords ***",
                "IT COMMON - Run Dut Command And Return",
                "    [Arguments]    ${command}",
                "    ${out}=    Fake.Fake Persisted Write    ${command}",
                "    RETURN    ${out}",
                "IT ASC - Live Configuration Should Equal",
                "    [Arguments]    @{args}",
                "    No Operation",
                "IT ASC - Persisted Configuration Should Equal",
                "    [Arguments]    @{args}",
                "    No Operation",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "persisted-restore.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "valid", output.getvalue())
                self.assertNotIn("Suite teardown failed", output.getvalue())

    def test_external_signal_suites_are_skipped_and_resolve_keywords(self):
        for item in ("ASC-004", "ASC-005", "ASC-013", "ASC-029"):
            spec = next(spec for spec in writer.SUITES if spec["id"] == item)
            self.assertTrue(all("robot:skip" in case["tags"] for case in spec["cases"]))
            text = writer.render(spec).replace(
                "Resource    ../__init_resource.robot",
                f"Resource    {ROOT / 'IT' / 'ASC' / '__init_resource.robot'}",
            ).replace("    robot:skip", "")
            with self.subTest(item=item), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "external.robot"
                path.write_text(text)
                output = io.StringIO()
                status = run(str(path), dryrun=True, output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status, 0, output.getvalue())

    def run_asc009(self, scenario):
        case = next(spec for spec in writer.SUITES if spec["id"] == "ASC-009")["cases"][0]
        lines = [
            "*** Settings ***",
            f"Resource    {ROOT / 'resource' / 'Common' / 'IT_Common.resource'}",
            f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
            "Suite Teardown    Should Be True    ${cleaned}",
            "*** Variables ***",
            f"${{scenario}}    {scenario}",
            "${cleaned}    ${FALSE}",
            "*** Test Cases ***",
            "Snapshot dump",
            *("    " + writer._var_line(name, value) for name, value in case["vars"]),
            *("    " + line for line in case["body"]),
            "*** Keywords ***",
            "IT COMMON - Run Dut Command And Return",
            "    [Arguments]    ${command}    ${timeout}=15",
            "    ${out}=    Fake.Fake Asc009 Command    ${command}    ${timeout}",
            "    RETURN    ${out}",
            "IT COMMON - Run Dut Root Command And Return",
            "    [Arguments]    ${command}    ${timeout}=15",
            "    ${out}=    Fake.Fake Asc009 Root    ${command}    ${timeout}",
            "    RETURN    ${out}",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "asc009.robot"
            path.write_text("\n".join(lines) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
            return status, output.getvalue()

    def test_snapshot_dump_compares_contents_and_cleans_up(self):
        for scenario in ("valid", "wrong-bin-count", "missing-rf-state", "wrong-pilot",
                         "empty-fdx-disabled", "empty-fdx-enabled"):
            with self.subTest(scenario=scenario):
                status, output = self.run_asc009(scenario)
                self.assertEqual(status == 0, scenario in ("valid", "empty-fdx-disabled"), output)
                self.assertNotIn("Suite teardown failed", output)

    def test_restore_attempts_every_field_even_when_one_write_fails(self):
        for scenario in ("valid", "set-fails"):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "Suite Teardown    Length Should Be    ${writes}    4",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "*** Test Cases ***",
                "Restore",
                "    VAR    &{state}    operationMode=FreeRun    inputInterval=300    inputPowerTransientThreshold=0    thirdPilotFrequency=1095000000    scope=SUITE",
                "    VAR    @{writes}    scope=SUITE",
                "    IT ASC - Restore ASC Configuration    Monitor    120    0.5    903000000",
                "*** Keywords ***",
                "IT COMMON - Run Dut Command And Return",
                "    [Arguments]    ${command}    ${timeout}=15",
                "    ${out}=    Fake.Fake Restore Command    ${command}",
                "    RETURN    ${out}",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "restore.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "valid", output.getvalue())
                self.assertNotIn("Suite teardown failed", output.getvalue())

    def test_np_ds_state_checks_do_not_depend_on_loop_count(self):
        for scenario, keyword, succeeds in (
            ("running", "IT ASC - NP DS Should Be Running", True),
            ("idle", "IT ASC - NP DS Should Be Running", False),
            ("idle", "IT ASC - NP DS Should Be Idle", True),
            ("running", "IT ASC - NP DS Should Be Idle", False),
            ("disabled", "IT ASC - NP DS Should Be Idle", False),
        ):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "*** Test Cases ***",
                "Check state",
                f"    {keyword}",
                "*** Keywords ***",
                "IT COMMON - Run Dut Command And Return",
                "    [Arguments]    ${command}",
                "    ${out}=    Fake.Fake Np Ds Status    ${command}",
                "    RETURN    ${out}",
            ]
            with self.subTest(scenario=scenario, keyword=keyword), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "np_ds.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, succeeds, output.getvalue())

    def test_reboot_wait_rejects_early_ssh_before_boot_id_changes(self):
        for scenario in ("rebooted", "no-reboot"):
            lines = [
                "*** Settings ***",
                f"Resource    {ROOT / 'resource' / 'Common' / 'IT_ASC.resource'}",
                f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
                "*** Variables ***",
                f"${{scenario}}    {scenario}",
                "${calls}    ${0}",
                "*** Test Cases ***",
                "Wait for reboot",
                "    Wait Until Keyword Succeeds    1s    0.05s    IT ASC - Confirm DUT Reboot    11111111-1111-1111-1111-111111111111",
                "*** Keywords ***",
                "IT COMMON - Wait For Dut To Come Back",
                "    [Arguments]    ${timeout}=20    ${interval}=5",
                "    Set Suite Variable    ${calls}    ${{int($calls) + 1}}",
                "IT COMMON - Run Dut Root Command And Return",
                "    [Arguments]    ${command}",
                "    ${out}=    Fake.Fake Boot Id    ${command}",
                "    RETURN    ${out}",
            ]
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "reboot.robot"
                path.write_text("\n".join(lines) + "\n")
                output = io.StringIO()
                status = run(str(path), output=None, log=None, report=None,
                             stdout=output, stderr=output)
                self.assertEqual(status == 0, scenario == "rebooted", output.getvalue())
