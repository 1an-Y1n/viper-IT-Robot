import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

from robot import run
from robot.api import TestSuite
from robot.libraries.BuiltIn import BuiltIn

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "IT" / "_generator"))
import writer
from sheet_alignment import (ALIGNMENT_TYPES, _alignment_gnmi_case, _ds_profile_case,
                             _spectrum_case, _nafe_case, _us_profile_rlsp_case)
sys.path.insert(0, str(ROOT / "lib" / "Viper"))
from GrpcJson import check_calibration_status, check_calibration_stream

PATH = "amp-alignment[alignment-type=ALIGN_DOWNSTREAM_STAGE_1]/alignment-status"


def progress(stage):
    return {"progress": {"status": "CALIBRATION_STAGE_" + stage}}


def next_subscription_response(timeout):
    status = BuiltIn().get_variable_value("${events}").pop(0)
    return {"updates": [{
        "Path": PATH,
        "values": {"amp-alignment/alignment-status": status},
    }]}


def fake_alignment_get(path):
    mode = BuiltIn().get_variable_value("${mode}")
    if path.endswith("*]"):
        types = list(ALIGNMENT_TYPES)
        if mode == "duplicate":
            types.append(types[0])
        return [{"updates": [
            {"Path": f"amp-alignment[alignment-type={item}]",
             "values": {"amp-alignment": {"alignment-type": item}}}
            for item in types
        ]}]
    item = path.split("alignment-type=", 1)[1].split("]", 1)[0]
    timestamp = "not-a-time" if mode == "bad-time" else "1970-01-01T04:26:48.993Z"
    data = {"alignment-type": item, "alignment-status": "ALIGN_STATUS_ALIGNED",
            "alignment-status-update-time": timestamp}
    if path.endswith("]"):
        return [{"updates": [{"Path": path, "values": {"amp-alignment": data}}]}]
    leaf = path.rsplit("/", 1)[1]
    return [{"updates": [{"Path": path, "values": {f"amp-alignment/{leaf}": data[leaf]}}]}]


def fake_fdx_command(view, command, timeout=15):
    builtin = BuiltIn()
    scenario = builtin.get_variable_value("${scenario}")
    if command == "show configuration":
        if view.startswith("ds-profile"):
            power = "30.00" if scenario == "wrong-power" else "32.00"
            step = "1218000000" if scenario == "wrong-step" else "1002000000"
            return (f"name  profile-4\nstart-freq  108000000 Hz\nstart-power  {power} dBmV\n"
                    f"end-freq  1218000000 Hz\nend-power  53.00 dBmV\n"
                    f"step-index:0 start-freq  {step} Hz\nstep-index:0 size-db  0.00 dBmV")
        if view.startswith("us-profile"):
            return "rlsp  8.00 dBmV"
        count = builtin.get_variable_value("${subbands}")
        mode = "bidi" if scenario == "wrong-mode" else "us"
        end = "684000000" if scenario == "wrong-range" else "396000000"
        result = (f"ds-start-freq  108000000 Hz\nds-end-freq  1218000000 Hz\n"
                  f"us-legacy-start-freq  5000000 Hz\nus-legacy-end-freq  85000000 Hz\n"
                  f"us-extended-start-freq  108000000 Hz\nus-extended-end-freq  {end} Hz\n"
                  f"Total subbands  {count}\n"
                  + "".join(f'subBand:{i} mode  "{mode}"\n' for i in range(count)))
        if not builtin.get_variable_value("${added}"):
            return result + "Total frequency exclusions  0\n"
        exclusion_type = "INTERFERENCE" if scenario == "wrong-exclusion" else "EXCLUDED"
        return (result + "Total frequency exclusions  1\nFreq-Exclusion:0 start-hz  383000000 Hz\n"
                "Freq-Exclusion:0 end-hz  396000000 Hz\nFreq-Exclusion:0 ds-fe-type  PASS_OTHER\n"
                f"Freq-Exclusion:0 us-fe-type  {exclusion_type}\n")
    if command == "commit":
        builtin.set_suite_variable("${commits}", builtin.get_variable_value("${commits}") + 1)
        return "failed to apply local configuration" if scenario == "commit-fails" else "applied local configuration"
    if command.startswith("subband add "):
        builtin.set_suite_variable("${adds}", builtin.get_variable_value("${adds}") + 1)
        if scenario == "add-fails":
            return "failed to add subband"
        builtin.set_suite_variable("${subbands}", builtin.get_variable_value("${subbands}") + 1)
        return "successfully added mode " + command.split()[-1]
    if command.startswith("subband "):
        return "failed to set subband-mode" if scenario == "set-fails" else '"subband-mode" is set from ds to us'
    if command.startswith("add freq-exclusion"):
        builtin.set_suite_variable("${added}", True)
        return "successfully added frequency exclusion"
    if command.startswith("step-down 0 start-freq"):
        builtin.set_suite_variable("${step_command}", command)
    if view == "spectrum" and "-freq " in command:
        return "frequency is set from old to new"
    return "configured"


def fake_offset_command(command):
    builtin = BuiltIn()
    if command.startswith("cat "):
        return builtin.get_variable_value("${offset}")
    value = command.split()[1]
    if value != "-1.5" or builtin.get_variable_value("${scenario}") != "restore-fails":
        builtin.set_suite_variable("${offset}", value)
    return ""


def fake_nafe_command(command, timeout=15):
    builtin = BuiltIn()
    scenario = builtin.get_variable_value("${scenario}")
    if command.startswith("sc_cli set_legacy_rlsp"):
        return "Set legacy rlsp failed" if scenario == "legacy-set-fails" else "Set legacy rlsp Success"
    if command.startswith("sc_cli get_legacy_rlsp"):
        port = command.split()[-1].capitalize()
        value = "7.0" if scenario == "legacy-wrong-read" and port == "South" else "8.0"
        return f"{port} Port rlsp: {value} dBmv"
    if command.endswith("set_ignore_np_ds_calib_adj 1"):
        builtin.set_suite_variable("${flag}", 1)
    elif command.endswith("set_ignore_np_ds_calib_adj 0"):
        builtin.set_suite_variable("${flag}", 0)
    elif command.endswith("get_ignore_np_ds_calib_adj"):
        return "get_ignore_np_ds_calib_adj = " + str(builtin.get_variable_value("${flag}"))
    elif command.startswith("sc_cli calib_nafe"):
        if scenario == "calibration-fails":
            return "calib_nafe failed"
        return "calib_nafe success"
    return "success"


def fake_legacy_journal(command, timeout=15):
    scenario = BuiltIn().get_variable_value("${scenario}")
    cursor = "s=abc;i=123;b=def;m=456;t=789;x=abc"
    if not command.startswith("SYSTEMD_COLORS=0 journalctl "):
        raise AssertionError("Journal output must be color-free")
    if "--show-cursor" in command:
        return "-- cursor: " + (cursor if scenario != "invalid-cursor" else cursor + ";unsafe")
    if "--after-cursor" not in command or f"--after-cursor '{cursor}'" not in command:
        raise AssertionError("Journal was not restricted to the captured cursor")
    if scenario == "stale-only":
        return ""
    if scenario == "journal-error":
        return "Failed to read journal"
    operational = "0" if scenario == "not-operational" else "1"
    message = (f"INFO ExecutePostUs1 - isCmOperational={operational}\n"
               "ecmTxPwrF1=32.4\necmTxPwrF2=32.8\n"
               "minEcmTxPower=17.25\nmaxEcmTxPower=52.75")
    entry = json.dumps({"MESSAGE": message})
    return entry + ("\n" + entry if scenario == "multiple-records" else "")


def fake_legacy_dut(command):
    if "set_legacy_up_jxp_tilt" in command:
        return "set_legacy_up_jxp_tilt...success"
    if "get_legacy_up_jxp_tilt" in command:
        return "get_legacy_up_jxp_tilt = 0"
    raise AssertionError("Unexpected device command: " + command)


def fake_legacy_calibration(view, command, timeout=15):
    BuiltIn().set_suite_variable("${calibration_ran}", True)
    if BuiltIn().get_variable_value("${scenario}") == "calibration-fails":
        return "calib_us_legacy failed"
    return "calib_us_legacy success by eCM Tx Power"


class AlignmentSequenceTest(unittest.TestCase):
    def test_aln007_is_skipped_before_setup(self):
        spec = next(spec for spec in writer.SUITES if spec["id"] == "ALN-007")
        text = writer.render(spec).replace(
            "Resource    ../__init_resource.robot", ""
        ).replace(
            "Suite Setup    Suite Initialization", "Suite Setup    Fail    Setup must not run"
        ).replace(
            "Suite Teardown   Suite Teardown", "Suite Teardown    Fail    Teardown must not run"
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "aln007.robot"
            path.write_text(text)
            suite = TestSuite.from_file_system(str(path))
            result = suite.run(output=None, log=None, report=None, stdout=io.StringIO())
        self.assertEqual(len(result.suite.tests), 6)
        self.assertEqual(result.suite.status, "SKIP")
        self.assertTrue(all(test.status == "SKIP" for test in result.suite.tests))

    def run_generated_case(self, case, scenario, extra=None, teardown=None):
        suite = [
            "*** Settings ***",
            f"Resource    {ROOT / 'resource' / 'Common' / 'IT_Common.resource'}",
            f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
            *(["Suite Teardown    Check Teardown"] if teardown else []),
            "*** Variables ***",
            f"${{scenario}}    {scenario}",
            "${added}    ${FALSE}",
            "${adds}    ${0}",
            "${subbands}    " + ("${0}" if scenario in ("empty", "add-fails") else
                                 "${2}" if scenario == "one-missing" else
                                 "${4}" if scenario == "too-many" else "${3}"),
            "${commits}    ${0}",
            "${step_command}    ${EMPTY}",
            "${offset}    -1.5",
            "${flag}    ${0}",
            "${ALN007_ORIGINAL_OFFSET}    ${NONE}",
            "${ALN007_BASE_OFFSET}    ${NONE}",
            "*** Test Cases ***",
            "Generated case",
            *("    " + line for line in case["body"]),
            "*** Keywords ***",
            "IT COMMON - Fdx Enter View",
            "    [Arguments]    ${command}    ${view}",
            "    RETURN    ok",
            "IT COMMON - Fdx Exit View",
            "    [Arguments]    ${view}",
            "    RETURN    ok",
            "IT COMMON - Run Fdx View Command And Return",
            "    [Arguments]    ${view}    ${command}    ${timeout}=15",
            "    ${out}=    Fake.Fake Fdx Command    ${view}    ${command}    ${timeout}",
            "    RETURN    ${out}",
            "IT COMMON - Run Dut Command And Return",
            "    [Arguments]    ${command}    ${timeout}=15",
            "    IF    $command.startswith('cat ')",
            "        ${out}=    Fake.Fake Offset Command    ${command}",
            "    ELSE",
            "        ${out}=    Fake.Fake Nafe Command    ${command}    ${timeout}",
            "    END",
            "    RETURN    ${out}",
            "IT COMMON - Run Dut Root Command And Return",
            "    [Arguments]    ${command}",
            "    ${out}=    Fake.Fake Offset Command    ${command}",
            "    RETURN    ${out}",
        ]
        if teardown:
            suite.append("Check Teardown")
            suite.extend("    " + line for line in teardown)
            if extra:
                suite.extend("    " + line for line in extra)
        elif extra:
            suite.extend(["Check Teardown", *("    " + line for line in extra)])
            suite.insert(3, "Suite Teardown    Check Teardown")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "generated.robot"
            path.write_text("\n".join(suite) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
            return status, output.getvalue()

    def test_profile_checks_power_and_template_step(self):
        case = _ds_profile_case("ALN-004", "north", "profile-4", "108000000", "32.0", "1218000000", "53.0")
        for scenario in ("valid", "wrong-power", "wrong-step"):
            with self.subTest(scenario=scenario):
                status, output = self.run_generated_case(
                    case, scenario, extra=["Should Be Equal    ${step_command}    step-down 0 start-freq 1002000000"])
                self.assertEqual(status == 0, scenario == "valid", output)

    def test_spectrum_adds_missing_and_rejects_bad_configuration(self):
        case = _spectrum_case("ALN-005", "108000000", "396000000", "us",
                              "383000000 396000000 PASS_OTHER EXCLUDED")
        for scenario in ("valid", "empty", "one-missing", "add-fails", "too-many",
                         "set-fails", "commit-fails", "wrong-mode", "wrong-range", "wrong-exclusion"):
            with self.subTest(scenario=scenario):
                expected_adds = {"valid": 0, "empty": 3, "one-missing": 1}
                extra = (["Should Be Equal As Integers    ${adds}    %s" % expected_adds[scenario]]
                         if scenario in expected_adds else
                         ["Should Be Equal As Integers    ${commits}    0"]
                         if scenario != "commit-fails" else None)
                status, output = self.run_generated_case(case, scenario, extra=extra)
                self.assertEqual(status == 0, scenario in expected_adds, output)
                self.assertNotIn("Suite teardown failed", output)

    def test_legacy_rlsp_checks_set_and_both_readbacks(self):
        for scenario in ("valid", "legacy-set-fails", "legacy-wrong-read"):
            with self.subTest(scenario=scenario):
                status, output = self.run_generated_case(_us_profile_rlsp_case("ALN-004"), scenario)
                self.assertEqual(status == 0, scenario == "valid", output)

    def test_negative_offset_restored_and_restore_failure_reported(self):
        spec = next(spec for spec in writer.SUITES if spec["id"] == "ALN-007")
        case = spec["cases"][1]
        for scenario in ("valid", "restore-fails"):
            with self.subTest(scenario=scenario):
                status, output = self.run_generated_case(
                    case, scenario, teardown=spec["teardown"],
                    extra=["Should Be Equal    ${offset}    -1.5"] if scenario == "valid" else None)
                self.assertEqual(status == 0, scenario == "valid", output)
                if scenario == "restore-fails":
                    self.assertIn("eCM offset restoration failed", output)

    def test_nafe_flag_restored_after_calibration_failure(self):
        for scenario in ("valid", "calibration-fails"):
            with self.subTest(scenario=scenario):
                status, output = self.run_generated_case(
                    _nafe_case("ALN-005"), scenario, extra=["Should Be Equal As Integers    ${flag}    0"])
                self.assertEqual(status == 0, scenario == "valid", output)
                self.assertNotIn("Suite teardown failed", output)

    def test_failed_lineup_blocks_dependent_tests(self):
        spec = next(spec for spec in writer.SUITES if spec["id"] == "ALN-005")
        suite = [
            "*** Settings ***",
            f"Resource    {ROOT / 'resource' / 'Common' / 'IT_Common.resource'}",
            f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
            "*** Variables ***",
            "${scenario}    add-fails",
            "${added}    ${FALSE}",
            "${adds}    ${0}",
            "${subbands}    ${0}",
            "${commits}    ${0}",
            "${ALN_LINEUP_FAILED}    ${FALSE}",
            "*** Test Cases ***",
            "Spectrum",
            *("    " + line for line in spec["cases"][3]["body"]),
            "Dependent action",
            *("    " + line for line in spec["cases"][4]["body"]),
            "*** Keywords ***",
            "IT COMMON - Fdx Enter View",
            "    [Arguments]    ${command}    ${view}",
            "    RETURN    ok",
            "IT COMMON - Fdx Exit View",
            "    [Arguments]    ${view}",
            "    RETURN    ok",
            "IT COMMON - Run Fdx View Command And Return",
            "    [Arguments]    ${view}    ${command}    ${timeout}=15",
            "    ${out}=    Fake.Fake Fdx Command    ${view}    ${command}    ${timeout}",
            "    RETURN    ${out}",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "lineup_guard.robot"
            path.write_text("\n".join(suite) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
        self.assertNotEqual(status, 0, output.getvalue())
        self.assertIn("| SKIP |", output.getvalue())
        self.assertIn("A preceding lineup configuration failed", output.getvalue())

    def run_legacy_journal_checks(self, scenario):
        spec = next(spec for spec in writer.SUITES if spec["id"] == "ALN-007")
        suite = [
            "*** Settings ***",
            f"Resource    {ROOT / 'resource' / 'Common' / 'IT_Common.resource'}",
            f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
            "*** Variables ***",
            f"${{scenario}}    {scenario}",
            "${ALN007_CALIBRATION_LOG}    old stale record",
            "${calibration_ran}    ${FALSE}",
            "*** Test Cases ***",
            "Legacy calibration",
            *("    " + line for line in spec["cases"][2]["body"]),
            "Check fresh journal",
            *("    " + line for line in spec["cases"][3]["body"]),
            "*** Keywords ***",
            "IT COMMON - Run Dut Root Command And Return",
            "    [Arguments]    ${command}    ${timeout}=15",
            "    ${out}=    Fake.Fake Legacy Journal    ${command}    ${timeout}",
            "    RETURN    ${out}",
            "IT COMMON - Run Dut Command And Return",
            "    [Arguments]    ${command}",
            "    ${out}=    Fake.Fake Legacy Dut    ${command}",
            "    RETURN    ${out}",
            "IT COMMON - Fdx Enter View",
            "    [Arguments]    ${command}    ${view}",
            "    RETURN    ok",
            "IT COMMON - Fdx Exit View",
            "    [Arguments]    ${view}",
            "    RETURN    ok",
            "IT COMMON - Run Fdx View Command And Return",
            "    [Arguments]    ${view}    ${command}    ${timeout}=15",
            "    ${out}=    Fake.Fake Legacy Calibration    ${view}    ${command}    ${timeout}",
            "    RETURN    ${out}",
        ]
        if scenario == "invalid-cursor":
            suite[1:1] = ["Suite Teardown    Verify No Calibration"]
            suite += ["Verify No Calibration", "    Should Be Equal    ${calibration_ran}    ${FALSE}"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "legacy_journal.robot"
            path.write_text("\n".join(suite) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
            return status, output.getvalue()

    def test_legacy_journal_requires_one_fresh_operational_record(self):
        expected = {
            "valid": None,
            "not-operational": "eCM was not operational during legacy calibration",
            "stale-only": "Expected one new legacy calibration journal record, found 0",
            "multiple-records": "Expected one new legacy calibration journal record, found 2",
            "journal-error": "Failed to read journal",
            "calibration-fails": "No journal record from this suite's successful legacy calibration",
            "invalid-cursor": "No journal record from this suite's successful legacy calibration",
        }
        for scenario, error in expected.items():
            with self.subTest(scenario=scenario):
                status, output = self.run_legacy_journal_checks(scenario)
                self.assertEqual(status == 0, error is None, output)
                if error:
                    self.assertIn(error, output)
                self.assertNotIn("Suite teardown failed", output)

    def test_grpc_auto_requires_ordered_stages_and_success(self):
        events = [progress(stage) for stage in ("DS1", "DS1", "DS2", "DS3", "US1")]
        events.append({"success": {"status": "SUCCESS"}})
        self.assertEqual(check_calibration_stream(events, "AUTO"), "SUCCESS")
        with self.assertRaises(AssertionError):
            check_calibration_stream(events[:-1] + [{"failure": {"status": "FAILURE"}}], "AUTO")
        with self.assertRaises(AssertionError):
            check_calibration_stream([progress("DS1"), progress("DS3"), events[-1]], "AUTO")

    def test_grpc_manual_rejects_other_stages(self):
        events = [progress("DS1"), {"success": {"status": "SUCCESS"}}]
        self.assertEqual(check_calibration_stream(events, "MANUAL"), "SUCCESS")
        with self.assertRaises(AssertionError):
            check_calibration_stream([progress("DS1"), progress("DS2"), events[-1]], "MANUAL")

    def test_grpc_semi_auto_manual_adjustment(self):
        adjustment = {"adjustment": {"stage": "STAGE_DS1", "manualAdjustments": [
            {"type": "DS_IN_EQ", "adjustmentValue": 2}
        ]}}
        events = [progress("DS1"), adjustment]
        self.assertEqual(check_calibration_stream(events, "SEMI_AUTO"), "MANUAL_ADJUSTMENT")
        with self.assertRaises(AssertionError):
            check_calibration_stream(events + [progress("DS2")], "SEMI_AUTO")
        with self.assertRaises(AssertionError):
            check_calibration_stream([progress("DS1"), {"adjustment": {"stage": "STAGE_DS2"}}], "SEMI_AUTO")

    def test_grpc_status_rejects_missing_or_duplicate_stages(self):
        infos = [{"stage": "STAGE_" + stage, "status": "ALIGNED"}
                 for stage in ("DS1", "DS2", "DS3", "US1")]
        response = {"success": {"status": "SUCCESS"}, "stageInfos": infos}
        self.assertEqual(check_calibration_status(response), response)
        infos[0].pop("status")
        infos[0]["manualAdjustments"] = []
        self.assertEqual(check_calibration_status(response), response)
        response["stageInfos"] = infos[:-1] + [infos[0]]
        with self.assertRaises(AssertionError):
            check_calibration_status(response)

    def run_manual_guard(self, pending):
        spec = next(spec for spec in writer.SUITES if spec["id"] == "ALN-014")
        case = next(case for case in spec["cases"] if "manual mode" in case["name"])
        suite = [
            "*** Settings ***",
            f"Library    {ROOT / 'lib' / 'Viper' / 'GrpcJson.py'}    WITH NAME    GrpcJson",
            "Suite Teardown    Check Request",
            "*** Variables ***",
            f"${{ALN014_CALIBRATION_BLOCKED}}    ${{{str(pending).upper()}}}",
            "${called}    ${FALSE}",
            "${proto}    calibration.proto",
            "${start_method}    StartCalibration",
            "*** Test Cases ***",
            "Check manual guard",
            *("    " + writer._var_line(name, value) for name, value in case["vars"]),
            *("    " + line for line in case["body"]),
            "*** Keywords ***",
            "IT COMMON - Grpcurl And Return Json List",
            "    [Arguments]    ${proto}    ${method}    ${payload}    ${timeout}",
            "    VAR    ${called}    ${TRUE}    scope=SUITE",
            "    ${events}=    Evaluate    [{'progress': {'status': 'CALIBRATION_STAGE_DS1'}}, {'success': {'status': 'SUCCESS'}}]",
            "    RETURN    ${events}",
            "Check Request",
            "    Should Not Be Equal    ${called}    ${ALN014_CALIBRATION_BLOCKED}",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manual_guard.robot"
            path.write_text("\n".join(suite) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
            return status, output.getvalue()

    def test_manual_guard_allows_request_without_adjustment(self):
        status, output = self.run_manual_guard(False)
        self.assertEqual(status, 0, output)
        self.assertIn("| PASS |", output)

    def test_manual_guard_skips_request_for_pending_adjustment(self):
        status, output = self.run_manual_guard(True)
        self.assertEqual(status, 0, output)
        self.assertIn("SKIP", output)

    def run_calibration_chain(self, scenario):
        spec = next(spec for spec in writer.SUITES if spec["id"] == "ALN-014")
        suite = [
            "*** Settings ***",
            f"Library    {ROOT / 'lib' / 'Viper' / 'GrpcJson.py'}    WITH NAME    GrpcJson",
            "*** Variables ***",
            "${ALN014_CALIBRATION_BLOCKED}    ${FALSE}",
            "${proto}    calibration.proto",
            "${start_method}    StartCalibration",
            f"${{scenario}}    {scenario}",
            "*** Test Cases ***",
        ]
        for case in spec["cases"][:3]:
            suite.append(case["name"])
            suite.extend("    " + writer._var_line(name, value) for name, value in case["vars"])
            suite.extend("    " + line for line in case["body"])
        suite.extend([
            "*** Keywords ***",
            "IT COMMON - Grpcurl And Return Json List",
            "    [Arguments]    ${proto}    ${method}    ${payload}    ${timeout}",
            "    IF    '\"MANUAL\"' in $payload    Fail    Manual request must be blocked",
            "    IF    '\"AUTO\"' in $payload and $scenario == 'auto-fails'",
            "        ${events}=    Evaluate    [{'failure': {'status': 'FAILURE'}}]",
            "        RETURN    ${events}",
            "    END",
            "    IF    '\"SEMI_AUTO\"' in $payload",
            "        IF    $scenario == 'auto-fails'    Fail    Semi-auto request must be blocked",
            "        ${events}=    Evaluate    [{'progress': {'status': 'CALIBRATION_STAGE_DS1'}}, {'adjustment': {'stage': 'STAGE_DS1', 'manualAdjustments': [{'type': 'DS_IN_EQ'}]}}]",
            "        RETURN    ${events}",
            "    END",
            "    ${events}=    Evaluate    [{'progress': {'status': 'CALIBRATION_STAGE_' + s}} for s in ('DS1', 'DS2', 'DS3', 'US1')] + [{'success': {'status': 'SUCCESS'}}]",
            "    RETURN    ${events}",
        ])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "chain.robot"
            path.write_text("\n".join(suite) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
            return status, output.getvalue()

    def test_auto_failure_blocks_later_calibrations(self):
        status, output = self.run_calibration_chain("auto-fails")
        self.assertNotEqual(status, 0, output)
        self.assertEqual(output.count("| SKIP |"), 2, output)
        self.assertNotIn("request must be blocked", output)

    def test_semi_auto_adjustment_blocks_manual_calibration(self):
        status, output = self.run_calibration_chain("adjustment")
        self.assertEqual(status, 0, output)
        self.assertEqual(output.count("| SKIP |"), 1, output)
        self.assertNotIn("request must be blocked", output)

    def run_sequence(self, states):
        body = _alignment_gnmi_case("ALIGN_DOWNSTREAM_STAGE_1", [])["body"]
        start = body.index("${started}=    GNMI_IT.Next Subscription Response    timeout=120")
        end = body.index("GNMI_IT.Stop Subscription")
        suite = [
            "*** Settings ***",
            f"Library    {Path(__file__).resolve()}    WITH NAME    GNMI_IT",
            f"Library    {ROOT / 'lib' / 'Viper' / 'GnmiPath.py'}    WITH NAME    GnmiPath",
            "*** Test Cases ***",
            "Check subscription sequence",
            f"    VAR    ${{status_path}}    {PATH}",
            "    VAR    @{events}    " + "    ".join(states) + "    scope=TEST",
            *("    " + line for line in body[start:end]),
            "*** Keywords ***",
            "IT COMMON - Gnmi Get Leaf Value",
            "    [Arguments]    ${response}    ${path}",
            "    ${value}=    GnmiPath.Resolve    ${response}    ${path}",
            "    RETURN    ${value}",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sequence.robot"
            path.write_text("\n".join(suite) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
            return status, output.getvalue()

    def test_repeated_progress_before_success(self):
        status, output = self.run_sequence([
            "ALIGN_STATUS_IN_PROGRESS",
            "ALIGN_STATUS_IN_PROGRESS",
            "ALIGN_STATUS_ALIGNED",
        ])
        self.assertEqual(status, 0, output)

    def test_failure_is_not_accepted(self):
        status, output = self.run_sequence([
            "ALIGN_STATUS_IN_PROGRESS",
            "ALIGN_STATUS_FAILURE",
        ])
        self.assertNotEqual(status, 0, output)
        self.assertIn("ALIGN_STATUS_FAILURE", output)

    def run_get_checks(self, mode):
        spec = next(spec for spec in writer.SUITES if spec["id"] == "ALN-013")
        suite = [
            "*** Settings ***",
            "Library    Collections",
            f"Library    {Path(__file__).resolve()}    WITH NAME    Fake",
            f"Library    {ROOT / 'lib' / 'Viper' / 'GnmiPath.py'}    WITH NAME    GnmiPath",
            "*** Variables ***",
            "@{alignment_types}    " + "    ".join(ALIGNMENT_TYPES),
            f"${{mode}}    {mode}",
            "*** Test Cases ***",
        ]
        for case in spec["cases"]:
            suite.append(case["name"])
            for name, value in case["vars"]:
                suite.append("    " + writer._var_line(name, value))
            suite.extend("    " + line for line in case["body"])
        suite += [
            "*** Keywords ***",
            "IT COMMON - Gnmi Get And Return",
            "    [Arguments]    ${path}",
            "    ${response}=    Fake.Fake Alignment Get    ${path}",
            "    RETURN    ${response}",
            "IT COMMON - Gnmi Get All Values",
            "    [Arguments]    ${response}",
            "    ${values}=    GnmiPath.All Values    ${response}",
            "    RETURN    ${values}",
            "IT COMMON - Gnmi Get Leaf Value",
            "    [Arguments]    ${response}    ${path}",
            "    ${value}=    GnmiPath.Resolve    ${response}    ${path}",
            "    RETURN    ${value}",
            "IT COMMON - Gnmi Leaf Should Exist",
            "    [Arguments]    ${container}    ${leaf}",
            "    Dictionary Should Contain Key    ${container}    ${leaf}",
            "IT COMMON - Value Should Be One Of",
            "    [Arguments]    ${value}    ${allowed}",
            "    List Should Contain Value    ${allowed}    ${value}",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "get.robot"
            path.write_text("\n".join(suite) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
            return status, output.getvalue()

    def test_get_rejects_duplicate_type(self):
        status, output = self.run_get_checks("duplicate")
        self.assertNotEqual(status, 0, output)

    def test_get_rejects_malformed_timestamp(self):
        status, output = self.run_get_checks("bad-time")
        self.assertNotEqual(status, 0, output)
        self.assertIn("not-a-time", output)

    def test_get_accepts_valid_values(self):
        status, output = self.run_get_checks("valid")
        self.assertEqual(status, 0, output)

    def run_ratio_case(self, mode):
        spec = next(spec for spec in writer.SUITES if spec["id"] == "ALN-015")
        case = next(case for case in spec["cases"] if case["name"] == "Set and restore the NAFE ratio")
        suite = [
            "*** Settings ***",
            "Suite Teardown    Check Restoration",
            "*** Variables ***",
            "${value}    0.0078125",
            f"${{mode}}    {mode}",
            "*** Test Cases ***",
            "Check ratio restoration",
            *("    " + line for line in case["body"]),
            "*** Keywords ***",
            "IT COMMON - Read Live Nonvol Number",
            "    [Arguments]    ${path}",
            "    RETURN    ${value}",
            "IT COMMON - Run Dut Command And Return",
            "    [Arguments]    ${cmd}",
            "    ${new}=    Evaluate    $cmd.split()[-1]",
            "    IF    $new == '3'",
            "        VAR    ${value}    ${new}    scope=SUITE",
            "        IF    $mode == 'set-fails'",
            "            RETURN    set_interference_ratio_based failed",
            "        END",
            "    ELSE",
            "        IF    $mode == 'restore-fails'",
            "            RETURN    set_interference_ratio_based failed",
            "        END",
            "        VAR    ${value}    ${new}    scope=SUITE",
            "    END",
            "    RETURN    set_interference_ratio_based success",
            "IT COMMON - Dut Command Should Succeed",
            "    [Arguments]    ${cmd}",
            "    RETURN    value=${value}",
            "IT COMMON - Cli Inline Number Should Equal",
            "    [Arguments]    ${text}    ${key}    ${expected}",
            "    Should Be Equal    ${value}    ${expected}",
            "Check Restoration",
            "    IF    $mode != 'restore-fails'",
            "        Should Be Equal    ${value}    0.0078125",
            "    END",
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ratio.robot"
            path.write_text("\n".join(suite) + "\n")
            output = io.StringIO()
            status = run(str(path), output=None, log=None, report=None,
                         stdout=output, stderr=output)
            return status, output.getvalue()

    def test_ratio_restored_after_set_failure(self):
        status, output = self.run_ratio_case("set-fails")
        self.assertNotEqual(status, 0, output)
        self.assertNotIn("Suite teardown failed", output)
        self.assertIn("set_interference_ratio_based failed", output)

    def test_ratio_restoration_failure_is_reported(self):
        status, output = self.run_ratio_case("restore-fails")
        self.assertNotEqual(status, 0, output)
        self.assertIn("set_interference_ratio_based failed", output)

    def test_ratio_restored_after_success(self):
        status, output = self.run_ratio_case("valid")
        self.assertEqual(status, 0, output)


if __name__ == "__main__":
    unittest.main()
