"""The ASC sheet of the LE IT test template: ASC-001 to ASC-039.

ASC-012, ASC-014, ASC-022, ASC-024 and ASC-025 are not here: they
need the physical bench.

ASC-003 appears twice in the template, with two different content blocks.
Both of them belong to the same test item, so they are two test cases of one
suite.
"""

from writer import C, S

CLI_CONFIG = "CLI Configuration"
OPERATION_MODE = "OperationMode"
SAVE = "Config/Target Data save"
CLEAR = "Config/Target Data clear"
FLOWCHART = "Algorithm flowchart"
INTERVAL = "Interval"
TEMP_COMP = "Temperature compensation"
TELEMETRY = "Telemetry"
CLIPPING = "Clipping Monitor"
CONTROL = "Control & Status"
GATING = "Gating"
ROBUSTNESS = "Robustness"
GRPC_CONFIG = "GRPC Configuration Service"
AGC_FDX = "AGC with FDX Enablement (Workaround)"

# The four state machines of the ASC.
FSMS = ["sp_ds", "np_ds", "clipping", "np_us"]

# The operation modes of the ASC. The configuration carries the number, the
# CLI prints the name of the mode.
MODE_DISABLE = "0"
MODE_FREE_RUN = "1"
MODE_MONITOR = "2"
MODE_NAMES = {"0": "Disable", "1": "FreeRun", "2": "Monitor"}
# The other way round, for putting a mode back that was read as a name.
MODE_NUMBERS = {"Disable": "0", "FreeRun": "1", "Monitor": "2"}

SNAPSHOT_FIELDS = [
    ("tcp_fields", ["calib_npf_tcp", "calib_npd_tcp",
                    "calib_ds_spf_tcp", "target_soc_in_tcp"]),
    ("state_fields", [
        "np_ds_att_after_lna_attenuation_db",
        "np_ds_att_before_lna_attenuation_db",
        "np_ds_att_between_lnas_attenuation_db",
        "np_ds_inverse_eq_tilt_db", "np_ds_vceq_tilt_db",
        "sp_ds_1p2g_veq_tilt_db", "sp_ds_1p8g_veq_tilt_db",
        "sp_ds_att_attenuation_db", "us_fdx_in_att_attenuation_db",
        "us_fdx_out_att_attenuation_db", "us_fdx_out_vceq_tilt_db",
        "us_legacy_att_after_lna_attenuation_db",
        "us_legacy_att_before_lna_attenuation_db",
    ]),
    ("bin_fields", ["pilot_wbfft", "np_ds_reference_dsis",
                    "sp_ds_target_spectrum", "np_f_reference_spectrum",
                    "fdx_path_gain_cal"]),
]


def _snapshot_comparison(indent=""):
    return [indent + line for line in [
        "${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
        "${fdx_enabled}=    IT COMMON - Get Cli Field    ${agc}    Fdx enable",
        "Should Be True    $fdx_enabled in ('true', 'false')    msg=Invalid FDX enable state",
        "${summary}=    IT COMMON - Run Dut Root Command And Return    jq -Mce 'select([.pilot_wbfft,.np_ds_reference_dsis,.sp_ds_target_spectrum,.np_f_reference_spectrum,.fdx_path_gain_cal] | all(type == \"array\")) | {calib_npf_tcp,calib_npd_tcp,calib_ds_spf_tcp,target_soc_in_tcp,calibration_state,pilot_goertzel,counts:{pilot_wbfft:(.pilot_wbfft|length),np_ds_reference_dsis:(.np_ds_reference_dsis|length),sp_ds_target_spectrum:(.sp_ds_target_spectrum|length),np_f_reference_spectrum:(.np_f_reference_spectrum|length),fdx_path_gain_cal:(.fdx_path_gain_cal|length)}}' ${snapshot_file}    timeout=120",
        "${parsed}=    Evaluate    json.loads($summary)    modules=json",
        "FOR    ${field}    IN    @{tcp_fields}",
        "    ${actual}=    IT COMMON - Get Cli Field    ${show}    ${field}",
        "    ${expected}=    Get From Dictionary    ${parsed}    ${field}",
        "    Should Be True    abs(float($actual.split()[0]) - float($expected)) <= 0.01    msg=Snapshot TCP ${field} differs from show",
        "END",
        "${state}=    Get From Dictionary    ${parsed}    calibration_state",
        "FOR    ${field}    IN    @{state_fields}",
        "    ${actual}=    IT COMMON - Get Text After Label    ${show}    ${field}",
        "    ${expected}=    Get From Dictionary    ${state}    ${field}",
        "    Should Be True    abs(float($actual.split()[0]) - float($expected)) <= 0.01    msg=Snapshot RF state ${field} differs from show",
        "END",
        "${pilots}=    Get From Dictionary    ${parsed}    pilot_goertzel",
        "${pilot_count}=    IT COMMON - Get Cli Field    ${show}    pilot_goertzel",
        "Should Be Equal As Integers    ${pilot_count.split()[0]}    ${{len($pilots)}}",
        "Should Not Be Empty    ${pilots}",
        "FOR    ${pilot}    IN    @{pilots}",
        "    ${freq}=    Get From Dictionary    ${pilot}    freq",
        "    ${value}=    Get From Dictionary    ${pilot}    value",
        "    ${actual}=    IT COMMON - Get Text After Label    ${show}    ${freq} Hz",
        "    Should Be True    abs(float($actual.split()[0]) - float($value)) <= 0.01    msg=Snapshot pilot ${freq} differs from show",
        "END",
        "${counts}=    Get From Dictionary    ${parsed}    counts",
        "FOR    ${field}    IN    @{bin_fields}",
        "    ${actual}=    IT COMMON - Get Cli Field    ${show}    ${field}",
        "    ${count}=    Get From Dictionary    ${counts}    ${field}",
        "    IF    $field != 'fdx_path_gain_cal' or $fdx_enabled == 'true'",
        "        Should Be True    int($count) > 0    msg=Snapshot ${field} is empty",
        "    END",
        "    Should Be Equal As Integers    ${actual.split()[0]}    ${count}    msg=Snapshot bin count ${field} differs from show",
        "END",
    ]]


def _set_asc_config(key, value):
    """The CLI command that sets one field of the ASC configuration."""
    return "sc_cli set_asc_config %s %s" % (key, value)


def _asc_config_case(item_id, changes, log, title, restore=True):
    """Set a few fields of the ASC configuration and read them back."""
    body = []
    if restore:
        body.append("${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config")
        for key, _ in changes:
            body.append("${old_%s}=    IT COMMON - Get Cli Field    ${before}    %s" % (key, key))
        if any(key == "operationMode" for key, _ in changes):
            body.append("${old_mode_number}=    Get From Dictionary    ${mode_numbers}    ${old_operationMode}")
    for key, value in changes:
        body.append("${set_%s}=    IT COMMON - Run Dut Command And Return    %s" % (key, _set_asc_config(key, value)))
    body.append("${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config")
    body.append("Log    ${config}")
    for key, value in changes:
        if key == "operationMode":
            # The configuration carries the number of the mode, the CLI prints
            # its name, so this one is compared as a string.
            body.append("IT COMMON - Cli Field Should Equal    ${config}    %s    %s" % (key, MODE_NAMES[value]))
        else:
            body.append("IT COMMON - Cli Number Should Equal    ${config}    %s    %s" % (key, value))
    if restore:
        body.append("# The values that were in place before the case are put back at the end.")
        for key, _ in changes:
            if key == "operationMode":
                body.append("${restore_%s}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode ${old_mode_number}" % key)
            else:
                body.append("${restore_%s}=    IT COMMON - Run Dut Command And Return    %s" % (key, _set_asc_config(key, "${old_%s}" % key)))
    return C(
        title,
        doc=[
            "Step 1. Set the configuration: %s" % ", ".join("%s = %s" % (key, value) for key, value in changes),
            "Step 2. Read the configuration back",
            "Step 3. Check that every value took",
        ],
        tags=["CLI", "WRITE"],
        log=log,
        vars=[("mode_numbers", MODE_NUMBERS)],
        body=body,
    )


def _attenuation_case(item_id, title, log):
    """Read the attenuation table of the RF board."""
    return C(
        title,
        doc=[
            "Step 1. GET the attenuation table of the RF board",
            "Step 2. Check that the eight attenuation entries are there",
        ],
        tags=["CLI"],
        log=log,
        body=[
            "${out}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
            "Log    ${out}",
            "Should Contain    ${out}    NP_DS_ATT_BEFORE_LNA",
            "Should Contain    ${out}    NP_DS_ATT_BETWEEN_LNAS",
            "Should Contain    ${out}    NP_DS_ATT_AFTER_LNA",
            "Should Contain    ${out}    US_FDX_IN_ATT",
            "Should Contain    ${out}    US_FDX_OUT_ATT",
            "Should Contain    ${out}    US_LEGACY_ATT_BEFORE_LNA",
            "Should Contain    ${out}    US_LEGACY_ATT_AFTER_LNA",
        ],
    )


S(
    "ASC-001",
    bench=True,
    sheet="ASC",
    area=CLI_CONFIG,
    comment="Set the ASC configuration and read it back",
    doc="Set the template ASC configuration, verify the NP DS timer and pilot "
        "trigger, reboot and verify persistence. Restore the original values.",
    cases=[
        C(
            "Set the ASC configuration and read it back",
            doc=[
                "Step 1. Check that the NP DS loop is enabled and save the configuration",
                "Step 2. Set the template values and check their readback",
                "Step 3. Check that the pilot change triggers NP DS and the 300 s timer runs",
                "Step 4. Reboot and check that all four values persisted",
                "Step 5. Restore and verify the original configuration and log level",
            ],
            tags=["CLI", "WRITE"],
            log="1_asc_config.log",
            vars=[("levels", {"EMERG": "0", "ALERT": "1", "CRIT": "2",
                              "ERR": "3", "WARN": "4", "NOTE": "5",
                              "INFO": "6", "DEBUG": "7"})],
            body=[
                "Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${mode}=    IT COMMON - Get Cli Field    ${before}    operationMode",
                "${interval}=    IT COMMON - Get Cli Field    ${before}    inputInterval",
                "${threshold}=    IT COMMON - Get Cli Field    ${before}    inputPowerTransientThreshold",
                "${pilot}=    IT COMMON - Get Cli Field    ${before}    thirdPilotFrequency",
                "${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "${level_line}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "${level}=    Evaluate    $level_line.split()[0]",
                "${level_number}=    Get From Dictionary    ${levels}    ${level}",
                "TRY",
                "    ${debug}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 7",
                "    ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "    ${debug_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "    Should Start With    ${debug_level}    DEBUG",
                "    ${set_mode}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "    ${set_threshold}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputPowerTransientThreshold 0.0",
                "    IF    int($pilot) == 1095000000",
                "        ${set_alternate}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config thirdPilotFrequency 903000000",
                "        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    END",
                "    ${cursor}=    IT COMMON - Read Journal Cursor",
                "    ${set_pilot}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config thirdPilotFrequency 1095000000",
                "    Wait Until Keyword Succeeds    180s    2s    IT ASC - NP DS Should Be Running",
                "    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    ${set_short}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 120",
                "    ${set_interval}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 300",
                "    ${timer_start}=    Evaluate    time.monotonic()    modules=time",
                "    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "    IT COMMON - Cli Field Should Equal    ${config}    operationMode    FreeRun",
                "    IT COMMON - Cli Number Should Equal    ${config}    inputInterval    300",
                "    IT COMMON - Cli Number Should Equal    ${config}    inputPowerTransientThreshold    0.0",
                "    IT COMMON - Cli Number Should Equal    ${config}    thirdPilotFrequency    1095000000",
                "    ${journal_cmd}=    Set Variable    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'",
                "    ${journal}=    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    NP DS loop timer armed: 300s    timeout=60    interval=5",
                "    Should Contain    ${journal}    Pilot 3 changed to 1095000000 Hz",
                "    WHILE    time.monotonic() - $timer_start < 270",
                "        IT ASC - NP DS Should Be Idle",
                "        Sleep    5s",
                "    END",
                "    Wait Until Keyword Succeeds    90s    2s    IT ASC - NP DS Should Be Running",
                "    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    ${boot_id}=    IT ASC - Get DUT Boot ID",
                "    Run Keyword And Ignore Error    IT COMMON - Run Fdx Command And Return    reset",
                "    Wait Until Keyword Succeeds    900s    10s    IT ASC - Confirm DUT Reboot    ${boot_id}",
                "    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "    IT COMMON - Cli Field Should Equal    ${after}    operationMode    FreeRun",
                "    IT COMMON - Cli Number Should Equal    ${after}    inputInterval    300",
                "    IT COMMON - Cli Number Should Equal    ${after}    inputPowerTransientThreshold    0.0",
                "    IT COMMON - Cli Number Should Equal    ${after}    thirdPilotFrequency    1095000000",
                "FINALLY",
                "    Wait Until Keyword Succeeds    900s    10s    IT COMMON - Wait For Dut To Come Back    timeout=20    interval=5",
                "    Run Keyword And Continue On Failure    IT ASC - Restore ASC Configuration    ${mode}    ${interval}    ${threshold}    ${pilot}",
                "    ${restore_log}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l ${level_number}",
                "    ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "    ${restored_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "    Should Start With    ${restored_level}    ${level}",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-002",
    sheet="ASC",
    area=CLI_CONFIG,
    comment="Set the AGC configuration and read it back",
    doc="Verify that the AGC tuning configuration can be set and read back "
        "over sc_cli. The reboot and the factory reset are steps of the bench "
        "procedure.",
    cases=[
        C(
            "Enable the legacy flag and the eCM tracking of the AGC",
            doc=[
                "Step 1. Read the AGC configuration",
                "Step 2. Set the legacy flag (index 4) and the eCM tracking (index 8)",
                "Step 3. Read the configuration back and check both flags",
            ],
            tags=["CLI", "WRITE"],
            log="1_agc_config.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${legacy_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 3 1",
                "${ecm_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 8 1",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${after}",
                "Should Contain    ${after}    Legacy enable: true",
                "Should Contain    ${after}    Track eCM power enable: true",
            ],
        ),
        C(
            "Put the original AGC configuration back",
            doc=[
                "Step 1. Read the values that were in place before the case",
                "Step 2. Put the legacy flag and the eCM tracking back",
            ],
            tags=["CLI", "WRITE"],
            log="2_restore.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${legacy}=    IT COMMON - Get Cli Field    ${before}    Legacy enable",
                "${ecm}=    IT COMMON - Get Cli Field    ${before}    Track eCM power enable",
                "${legacy_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 3 0",
                "${ecm_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 8 0",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${after}",
            ],
        ),
    ],
)

S(
    "ASC-003",
    sheet="ASC",
    area=CLI_CONFIG,
    comment="Reset the AGC configuration and disable the ASC",
    doc="The template holds two content blocks under this id: the reset of the "
        "AGC configuration to its defaults and the ASC Disable mode. Both are "
        "two test cases of this suite.",
    cases=[
        C(
            "Set an AGC flag and check that it is stored",
            doc=[
                "Step 1. Set the FDX flag of the AGC configuration (index 5)",
                "Step 2. Read the configuration back",
                "Step 3. Check that /mnt/sc_nonvol/agc_data.json is there",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_agc_file.log",
            body=[
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 4 1",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${config}",
                "Should Contain    ${config}    Fdx enable: true",
                "${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/agc_data.json    timeout=60",
                "Should Not Be Equal    ${size}    0",
            ],
        ),
        C(
            "Reset the AGC configuration and check that it is readable",
            doc=[
                "Step 1. Run sc_cli reset_agc_config",
                "Step 2. Read the AGC configuration back",
                "Step 3. The template expects the file to be gone after the reset;",
                "        on this firmware it stays, so the check is that the",
                "        configuration is back to its defaults and still parses",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="2_agc_reset.log",
            body=[
                "${reset}=    IT COMMON - Run Dut Command And Return    sc_cli reset_agc_config",
                "Log    ${reset}",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${config}",
                # The reset leaves the file truncated, the ASC service writes
                # it again in one of its rounds, which takes up to its input
                # interval, so the wait is long.
                "${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/agc_data.json    timeout=300",
            ],
        ),
        C(
            "Disable the ASC and check that the control loops stop",
            doc=[
                "Step 1. Set the operation mode to Disable",
                "Step 2. Read the ASC configuration",
                "Step 3. Check that all four state machines report enabled = false",
                "Step 4. Try to start the AGC control, it has to be refused",
            ],
            tags=["CLI", "WRITE"],
            log="3_asc_disable.log",
            body=[
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Log    ${config}",
                "Should Contain    ${config}    operationMode = Disable",
            ] + [
                "${%s}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status %s" % (fsm, fsm)
                for fsm in FSMS
            ] + [
                "FOR    ${fsm}    IN    @{fsms}",
                "    ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled",
                "    Should Be Equal    ${state}    false",
                "END",
                "${start}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start",
                "Log    ${start}",
                "Should Contain    ${start}    failed",
            ],
            vars=[("fsms", FSMS)],
        ),
        C(
            "Put the ASC back into FreeRun mode",
            doc=[
                "Step 1. Set the operation mode back to FreeRun",
                "Step 2. Read the ASC configuration",
            ],
            tags=["CLI", "WRITE"],
            log="4_asc_enable.log",
            body=[
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Log    ${config}",
                "Should Contain    ${config}    operationMode = FreeRun",
            ],
        ),
    ],
)

S(
    "ASC-004",
    bench=True,
    sheet="ASC",
    area=OPERATION_MODE,
    comment="Run the ASC in FreeRun mode and check that it adjusts the RF",
    doc="Verify that FreeRun mode runs the control loops and adjusts the RF "
        "(User Guide 10.4). Skipped until north port signal control is implemented.",
    cases=[
        C(
            "Run the ASC in FreeRun mode",
            doc=[
                "Step 1. Check that the calibration snapshot holds data",
                "Step 2. Set FreeRun and verify the loops and ADU",
                "Step 3. Change the north port signal via the bench adapter",
                "Step 4. Wait for NP DS and check that RF attenuation changed",
                "Step 5. Restore the signal and original operation mode",
            ],
            tags=["CLI", "WRITE", "MANUAL_BENCH", "robot:skip"],
            log="1_free_run.log",
            body=[
                "${snapshot}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "${end_freq}=    IT COMMON - Get Cli Field    ${snapshot}    ds_end_frequency_hz",
                "Should Be True    int($end_freq.split()[0]) > 0    msg=Calibration snapshot is missing",
                "${pab}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                "${enabled}=    IT COMMON - Get Cli Field    ${pab}    Enabled",
                "${completed}=    IT COMMON - Get Cli Field    ${pab}    Completed",
                "Should Be True    $enabled == 'No' or $completed == 'Yes'    msg=PAB is not complete",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode",
                "${interval}=    IT COMMON - Get Cli Field    ${config}    inputInterval",
                "${timeout}=    Evaluate    max(int($interval), 120) + 180",
                "VAR    ${external_attempted}    ${FALSE}",
                "TRY",
                "    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "    IT COMMON - Cli Field Should Equal    ${config}    operationMode    FreeRun",
            ] + [
                "    ${%s}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status %s" % (fsm, fsm)
                for fsm in FSMS
            ] + [
                "    FOR    ${fsm}    IN    @{fsms}",
                "        ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled",
                "        Should Be Equal    ${state}    true",
                "    END",
                "    ${adu}=    IT COMMON - Run Dut Command And Return    sc_cli get_adu_status",
                "    ${adu_name}=    IT COMMON - Get Inline Field    ${adu}    name",
                "    Should Be Equal    ${adu_name}    TRACKING",
                "    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "    ${written_before}=    IT COMMON - Get Inline Values    ${before}    last_set",
                "    Should Not Be Empty    ${written_before}",
                "    VAR    ${external_attempted}    ${TRUE}",
                "    IT ASC EXTERNAL - Set North Port Input Delta    -3",
                "    Wait Until Keyword Succeeds    ${timeout}s    2s    IT ASC - NP DS Should Be Running",
                "    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "    ${written_after}=    IT COMMON - Get Inline Values    ${after}    last_set",
                "    Should Not Be Equal    ${written_after}    ${written_before}    msg=FreeRun did not change RF attenuation",
                "FINALLY",
                "    IF    $external_attempted",
                "        Run Keyword And Continue On Failure    IT ASC EXTERNAL - Restore North Port Signal",
                "    END",
                "    Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}",
                "END",
            ],
            vars=[("fsms", FSMS)],
        ),
    ],
)

S(
    "ASC-005",
    bench=True,
    sheet="ASC",
    area=OPERATION_MODE,
    comment="Run the ASC in Monitor mode and check that it does not write the RF",
    doc="Verify that Monitor mode runs the whole decision path without "
        "writing the RF (User Guide 10.4). Skipped until north port signal control is implemented.",
    cases=[
        C(
            "Run the ASC in Monitor mode",
            doc=[
                "Step 1. Set the operation mode to Monitor",
                "Step 2. Change the north port signal via the bench adapter",
                "Step 3. Verify the NP DS decision and unchanged RF attenuation",
                "Step 4. Restore the signal, log level and original operation mode",
            ],
            tags=["CLI", "WRITE", "MANUAL_BENCH", "robot:skip"],
            log="1_monitor.log",
            vars=[
                ("fsms", FSMS),
                ("levels", {"EMERG": "0", "ALERT": "1", "CRIT": "2",
                            "ERR": "3", "WARN": "4", "NOTE": "5",
                            "INFO": "6", "DEBUG": "7"}),
            ],
            body=[
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode",
                "${interval}=    IT COMMON - Get Cli Field    ${config}    inputInterval",
                "${timeout}=    Evaluate    max(int($interval), 120) + 180",
                "${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "${level_line}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "${level}=    Evaluate    $level_line.split()[0]",
                "${level_number}=    Get From Dictionary    ${levels}    ${level}",
                "VAR    ${external_attempted}    ${FALSE}",
                "TRY",
                "    ${debug}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 7",
                "    ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "    ${debug_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "    Should Start With    ${debug_level}    DEBUG",
                "    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 2",
                "    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "    IT COMMON - Cli Field Should Equal    ${config}    operationMode    Monitor",
            ] + [
                "    ${%s}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status %s" % (fsm, fsm)
                for fsm in FSMS
            ] + [
                "    FOR    ${fsm}    IN    @{fsms}",
                "        ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled",
                "        Should Be Equal    ${state}    true",
                "    END",
                "    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "    ${written_before}=    IT COMMON - Get Inline Values    ${before}    last_set",
                "    ${configured_before}=    IT COMMON - Get Inline Values    ${before}    config",
                "    Should Not Be Empty    ${written_before}",
                "    Should Not Be Empty    ${configured_before}",
                "    ${cursor}=    IT COMMON - Read Journal Cursor",
                "    VAR    ${external_attempted}    ${TRUE}",
                "    IT ASC EXTERNAL - Set North Port Input Delta    -3",
                "    Wait Until Keyword Succeeds    ${timeout}s    2s    IT ASC - NP DS Should Be Running",
                "    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    VAR    ${journal_cmd}    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'",
                "    ${journal}=    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    [NpDs][Measure] ASC is in monitor mode. Will not adjust RF components    timeout=60    interval=5",
                "    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "    ${written_after}=    IT COMMON - Get Inline Values    ${after}    last_set",
                "    ${configured_after}=    IT COMMON - Get Inline Values    ${after}    config",
                "    Should Be Equal    ${written_after}    ${written_before}",
                "    Should Be Equal    ${configured_after}    ${configured_before}",
                "FINALLY",
                "    IF    $external_attempted",
                "        Run Keyword And Continue On Failure    IT ASC EXTERNAL - Restore North Port Signal",
                "    END",
                "    Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}",
                "    ${restore_log}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l ${level_number}",
                "    ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "    ${restored_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "    Should Start With    ${restored_level}    ${level}",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-006",
    sheet="ASC",
    area=OPERATION_MODE,
    comment="Switch the ASC between Disable, FreeRun and Monitor",
    doc="Verify that switching between Disable, FreeRun and Monitor is clean "
        "(User Guide 10.4).",
    cases=[
        C(
            "Switch from Disable to FreeRun",
            doc=[
                "Step 1. Set the operation mode to Disable and read it back",
                "Step 2. Set the operation mode to FreeRun and read it back",
                "Step 3. Read the ADU status",
            ],
            tags=["CLI", "WRITE"],
            log="1_disable_to_free_run.log",
            body=[
                "${disable}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0",
                "${disabled_config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Should Contain    ${disabled_config}    operationMode = Disable",
                "${free_run}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Should Contain    ${config}    operationMode = FreeRun",
                "${adu}=    IT COMMON - Run Dut Command And Return    sc_cli get_adu_status",
                "Log    ${adu}",
            ],
        ),
        C(
            "Switch from FreeRun to Monitor and back",
            doc=[
                "Step 1. Set the operation mode to Monitor and read it back",
                "Step 2. Set the operation mode to Disable and read it back",
                "Step 3. Set the operation mode to FreeRun and read it back",
            ],
            tags=["CLI", "WRITE"],
            log="2_free_run_to_monitor.log",
            body=[
                "${monitor}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 2",
                "${monitor_config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Should Contain    ${monitor_config}    operationMode = Monitor",
                "${disable}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0",
                "${disabled_config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Should Contain    ${disabled_config}    operationMode = Disable",
                "${free_run}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Should Contain    ${config}    operationMode = FreeRun",
            ],
        ),
    ],
)

S(
    "ASC-007",
    bench=True,
    sheet="ASC",
    area=SAVE,
    comment="Check that the configuration is persisted in agc_data.json",
    doc="Verify that the configuration changes are persisted to "
        "agc_data.json and restored after a restart (User Guide 10.4).",
    cases=[
        C(
            "Persist ASC and AGC configuration across a service restart",
            doc=[
                "Step 1. Save and set the ASC and AGC configuration values from the template",
                "Step 2. Check both values in agc_data.json",
                "Step 3. Restart sc-asc and verify the persisted values and startup log",
                "Step 4. Restore the original values and verify them",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_persist.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${old_mode}=    IT COMMON - Get Cli Field    ${before}    operationMode",
                "${old}=    IT COMMON - Get Cli Field    ${before}    inputInterval",
                "${old_power}=    IT COMMON - Get Cli Field    ${before}    inputPowerTransientThreshold",
                "${agc_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${old_att}=    IT COMMON - Get Cli Field    ${agc_before}    pathloss change ATT Threshold",
                "${old_eq}=    IT COMMON - Get Cli Field    ${agc_before}    pathloss change EQ Threshold",
                "${old_notify}=    IT COMMON - Get Cli Field    ${agc_before}    Rfboard notify interval",
                "TRY",
                "    IT ASC - Set And Verify Persisted Configuration    FreeRun    300    0.2    0.5    0.5    3600",
                "    ${pid_before}=    IT COMMON - Run Dut Root Command And Return    systemctl --no-pager show -p MainPID --value sc-asc",
                "    ${pid_before}=    Evaluate    $pid_before.strip()",
                "    Should Match Regexp    ${pid_before}    ^[1-9][0-9]*$",
                "    ${cursor}=    IT COMMON - Read Journal Cursor",
                "    ${restart}=    IT COMMON - Run Dut Root Command And Return    systemctl restart sc-asc && echo SC_ASC_RESTART_OK    timeout=120",
                "    Should Contain    ${restart}    SC_ASC_RESTART_OK",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active",
                "    ${pid_after}=    IT COMMON - Run Dut Root Command And Return    systemctl --no-pager show -p MainPID --value sc-asc",
                "    ${pid_after}=    Evaluate    $pid_after.strip()",
                "    Should Match Regexp    ${pid_after}    ^[1-9][0-9]*$",
                "    Should Not Be Equal    ${pid_after}    ${pid_before}    msg=sc-asc did not restart",
                "    IT ASC - Live Configuration Should Equal    FreeRun    300    0.2    0.5    0.5    3600",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - Persisted Configuration Should Equal    FreeRun    300    0.2    0.5    0.5    3600",
                "    ${errors}=    IT COMMON - Run Dut Root Command And Return    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc --priority=err --after-cursor '${cursor}' -o cat",
                "    Should Be Empty    ${errors.strip()}    msg=sc-asc logged errors during restart: ${errors}",
                "FINALLY",
                "    SSH_IT_ROOT.Close",
                "    SSH_IT_ROOT.Connect    ssh_setting=${SSH_DUT_IT}    level=ROOT    main_log_name=${case_name}-ssh_root.log",
                "    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active",
                "    IT ASC - Set And Verify Persisted Configuration    ${old_mode}    ${old}    ${old_power}    ${old_att}    ${old_eq}    ${old_notify}",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-008",
    bench=True,
    sheet="ASC",
    area=SAVE,
    comment="Check that the calibration snapshot is stored and readable",
    doc="Verify that the calibration snapshot is saved and readable "
        "(User Guide 10.4).",
    cases=[
        C(
            "Check that the calibration snapshot is stored",
            doc=[
                "Step 1. Run a full automatic calibration",
                "Step 2. Compare the stored snapshot and show output",
                "Step 3. Reboot and repeat the comparison, checking the snapshot is unchanged",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_snapshot.log",
            vars=SNAPSHOT_FIELDS,
            body=[
                "IT COMMON - Fdx Enter View    configure calibration    calibration",
                "TRY",
                "    ${start}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration auto    timeout=600",
                "    IT COMMON - Progress Line Order    ${start}    DS1    DS2    DS3    US1",
                "    IT COMMON - Check Calibration Result    ${start}    0",
                "FINALLY",
                "    IT COMMON - Fdx Exit View    calibration",
                "END",
                "${snapshot_file}=    Set Variable    /mnt/sc_nonvol/asc_calib_snapshot.json",
                "${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/asc_calib_snapshot.json    timeout=60",
                "Should Not Be Equal    ${size}    0",
                "${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "${end_freq}=    IT COMMON - Get Cli Field    ${show}    ds_end_frequency_hz",
                "Should Be True    int($end_freq.split()[0]) > 0    msg=No calibration snapshot was saved",
                *_snapshot_comparison(),
                "${before_hash}=    IT COMMON - Run Dut Root Command And Return    sha256sum ${snapshot_file}",
                "Should Match Regexp    ${before_hash.strip()}    ^[0-9a-f]{64}\\\\s",
                "${boot_id}=    IT ASC - Get DUT Boot ID",
                "Run Keyword And Ignore Error    IT COMMON - Run Fdx Command And Return    reset",
                "Wait Until Keyword Succeeds    900s    10s    IT ASC - Confirm DUT Reboot    ${boot_id}",
                "${after_hash}=    IT COMMON - Run Dut Root Command And Return    sha256sum ${snapshot_file}",
                "Should Be Equal    ${after_hash.strip()}    ${before_hash.strip()}    msg=Snapshot file changed across reboot",
                "${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                *_snapshot_comparison(),
            ],
        ),
    ],
)

S(
    "ASC-009",
    sheet="ASC",
    area=SAVE,
    comment="Dump the calibration snapshot to a file",
    doc="Verify that the reference and the target data can be dumped to a "
        "designated file (User Guide 10.4).",
    cases=[
        C(
            "Dump the calibration snapshot",
            doc=[
                "Step 1. Read the stored calibration snapshot",
                "Step 2. Dump it to a unique temporary file",
                "Step 3. Compare the TCPs, pilots, RF state and spectrum bin counts",
                "Step 4. Remove the temporary file, including on failure",
            ],
            tags=["CLI", "FILE"],
            log="1_dump.log",
            vars=SNAPSHOT_FIELDS,
            body=[
                "${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "${end_freq}=    IT COMMON - Get Cli Field    ${show}    ds_end_frequency_hz",
                "Should Be True    int($end_freq.split()[0]) > 0    msg=No calibration snapshot to dump",
                "${dump_file}=    IT COMMON - Run Dut Root Command And Return    mktemp /tmp/it_asc009_XXXXXXXX",
                "${dump_file}=    Evaluate    $dump_file.strip()",
                "Should Match Regexp    ${dump_file}    ^/tmp/it_asc009_[A-Za-z0-9]+$",
                "TRY",
                "    ${dump}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot dump ${dump_file}    timeout=120",
                "    Should Contain    ${dump}    bytes written to ${dump_file}",
                "    ${snapshot_file}=    Set Variable    ${dump_file}",
                *_snapshot_comparison("    "),
                "FINALLY",
                "    ${removed}=    IT COMMON - Run Dut Root Command And Return    rm -f -- ${dump_file} && echo REMOVED",
                "    Should Contain    ${removed}    REMOVED",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-010",
    bench=True,
    sheet="ASC",
    area=CLEAR,
    comment="Clear the calibration snapshot",
    doc="Verify that asc_calib_snapshot clear removes the calibration "
        "snapshot (User Guide 10.4). The calibration that the template asks "
        "for is a step of the bench procedure.",
    cases=[
        C(
            "Clear the calibration snapshot and check it",
            doc=[
                "Step 1. Run sc_cli asc_calib_snapshot show, there has to be data",
                "Step 2. Run sc_cli asc_calib_snapshot clear",
                "Step 3. Run show again, it has to report no calibration",
                "Step 4. Check that the snapshot file is gone",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_clear.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "Log    ${before}",
                "${clear}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot clear",
                "Log    ${clear}",
                "Should Contain    ${clear}    asc_calib_snapshot clear done",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "Log    ${after}",
                "${end_freq}=    IT COMMON - Get Cli Field Or Default    ${after}    ds_end_frequency_hz    0",
                "Should Be Equal    ${end_freq}    0",
                "${out}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol/asc_calib_snapshot.json",
                "Log    ${out}",
                "Should Contain    ${out}    No such file",
            ],
        ),
    ],
)

S(
    "ASC-011",
    bench=True,
    sheet="ASC",
    area=CLEAR,
    comment="Reset the AGC and the ASC configuration to their defaults",
    doc="Verify that reset_agc resets the agc_config and the asc_config to "
        "their defaults and clears the calibration snapshot (User Guide 10.4).",
    cases=[
        C(
            "Reset the AGC configuration and check it",
            doc=[
                "Step 1. Change the ASC configuration and the AGC configuration",
                "Step 2. Run sc_cli reset_agc",
                "Step 3. Read both configurations back, they have to be the defaults",
                "Step 4. Run show again, the snapshot has to be cleared",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_reset.log",
            body=[
                "${set_asc}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 300",
                "${set_agc}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 1 0.5",
                "${reset}=    IT COMMON - Run Dut Command And Return    sc_cli reset_agc",
                "Log    ${reset}",
                "Should Contain    ${reset}    calibration snapshot cleared",
                "${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Log    ${asc}",
                "${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${agc}",
                "${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "Log    ${show}",
            ],
        ),
    ],
)

S(
    "ASC-013",
    bench=True,
    sheet="ASC",
    area=FLOWCHART,
    comment="The NP DS out-of-range handler returns the input toward the AGC window",
    doc="Create and then restore an out-of-range north port input. Skipped until "
        "external signal control is implemented and validated.",
    cases=[
        C(
            "Handle and recover from an out-of-range input",
            doc=[
                "Step 1. Save the original operation mode and log level",
                "Step 2. Lower the north port input relative to calibration",
                "Step 3. Check out-of-range adjustment and ON_HOLD",
                "Step 4. Restore the input and check that TRACKING resumes",
                "Step 5. Restore the operation mode and log level",
            ],
            tags=["CLI", "WRITE", "MANUAL_BENCH", "robot:skip"],
            log="1_out_of_range.log",
            vars=[("levels", {"EMERG": "0", "ALERT": "1", "CRIT": "2",
                              "ERR": "3", "WARN": "4", "NOTE": "5",
                              "INFO": "6", "DEBUG": "7"})],
            body=[
                "${snapshot}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "${end_freq}=    IT COMMON - Get Cli Field    ${snapshot}    ds_end_frequency_hz",
                "Should Be True    int($end_freq.split()[0]) > 0    msg=Calibration snapshot is missing",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode",
                "${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "${level_line}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "${level}=    Evaluate    $level_line.split()[0]",
                "${level_number}=    Get From Dictionary    ${levels}    ${level}",
                "VAR    ${external_attempted}    ${FALSE}",
                "TRY",
                "    ${debug}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 7",
                "    ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "    ${debug_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "    Should Start With    ${debug_level}    DEBUG",
                "    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "    IT COMMON - Cli Field Should Equal    ${config}    operationMode    FreeRun",
                "    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    ${cursor}=    IT COMMON - Read Journal Cursor",
                "    VAR    ${external_attempted}    ${TRUE}",
                "    IT ASC EXTERNAL - Set North Port Input Delta    -6",
                "    VAR    ${journal_cmd}    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'",
                "    ${start}=    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    Start 1st OutRange handler process    timeout=600    interval=10",
                "    ${boundary}=    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    SOC Input is adjusted to near AGC boundary    timeout=600    interval=10",
                "    ${hold}=    IT COMMON - Wait For Dut Command Contains    sc_cli get_adu_status    name=ON_HOLD    timeout=120    interval=5",
                "    IT ASC EXTERNAL - Restore North Port Signal",
                "    VAR    ${external_attempted}    ${FALSE}",
                "    ${tracking}=    IT COMMON - Wait For Dut Command Contains    sc_cli get_adu_status    name=TRACKING    timeout=600    interval=10",
                "FINALLY",
                "    IF    $external_attempted",
                "        Run Keyword And Continue On Failure    IT ASC EXTERNAL - Restore North Port Signal",
                "    END",
                "    Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}",
                "    ${restore_log}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l ${level_number}",
                "    ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli",
                "    ${restored_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc",
                "    Should Start With    ${restored_level}    ${level}",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-015",
    sheet="ASC",
    area=FLOWCHART,
    comment="The SP DS state machine corrects the output side drift",
    doc="Verify that the SP DS round corrects the output side drift "
        "(User Guide 10.4).",
    cases=[
        C(
            "Read the state of the SP DS machine",
            doc=[
                "Step 1. Read the SP DS state machine",
                "Step 2. Check that it carries the five fields of the state",
            ],
            tags=["CLI"],
            log="1_sp_ds.log",
            body=[
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status sp_ds",
                "Log    ${status}",
                "${fsm}=    IT COMMON - Get Cli Field    ${status}    fsm",
                "Should Be Equal    ${fsm}    SpDs",
                "${stage}=    IT COMMON - Get Cli Field    ${status}    current_stage",
                "Should Not Be Equal    ${stage}    ${EMPTY}",
                "${running}=    IT COMMON - Get Cli Field    ${status}    running_status",
                "Should Not Be Equal    ${running}    ${EMPTY}",
                "${loops}=    IT COMMON - Get Cli Field    ${status}    loop_count",
                "Should Not Be Equal    ${loops}    ${EMPTY}",
            ],
        ),
        _attenuation_case("ASC-015", "Read the attenuation table of the RF board", "2_attenuation.log"),
    ],
)

S(
    "ASC-016",
    sheet="ASC",
    area=FLOWCHART,
    comment="The NP US state machine tracks the eCM TX power",
    doc="Verify that the NP US round tracks the eCM TX power (User Guide 10.4).",
    cases=[
        C(
            "Check that the eCM is online and that the NP US machine is there",
            doc=[
                "Step 1. Check that the eCM is operational",
                "Step 2. Read the legacy flag and the eCM tracking flag of the AGC",
                "Step 3. Read the NP US state machine",
            ],
            tags=["CLI"],
            log="1_np_us.log",
            body=[
                "${cm}=    IT COMMON - Run Dut Command And Return    sc_cli get_snmp_cm_status",
                "Log    ${cm}",
                "Should Contain    ${cm}    eCM is OPERATIONAL",
                "${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${legacy}=    IT COMMON - Get Cli Field    ${agc}    Legacy enable",
                "${track}=    IT COMMON - Get Cli Field    ${agc}    Track eCM power enable",
                "Log    ${legacy}",
                "Log    ${track}",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us",
                "Log    ${status}",
                "${fsm}=    IT COMMON - Get Cli Field    ${status}    fsm",
                "Should Be Equal    ${fsm}    NpUs",
            ],
        ),
    ],
)

S(
    "ASC-017",
    sheet="ASC",
    area=INTERVAL,
    comment="The NP DS rounds run at the configured interval",
    doc="Verify that the NP DS rounds run at the configured interval "
        "(User Guide 10.4).",
    cases=[
        C(
            "Read the NP DS interval and change it",
            doc=[
                "Step 1. Read the input interval of the ASC",
                "Step 2. Set it to 300 s and read it back",
                "Step 3. Read the NP DS state machine, it carries the loop count",
            ],
            tags=["CLI", "WRITE"],
            log="1_interval.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    inputInterval",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 300",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "IT COMMON - Cli Number Should Equal    ${after}    inputInterval    300",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds",
                "Log    ${status}",
                "${loops}=    IT COMMON - Get Cli Field    ${status}    loop_count",
                "Should Not Be Equal    ${loops}    ${EMPTY}",
            ],
        ),
        C(
            "Put the original interval back",
            doc=[
                "Step 1. Put the input interval back",
                "Step 2. Read the configuration",
            ],
            tags=["CLI", "WRITE"],
            log="2_restore.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    inputInterval",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval ${old}",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "IT COMMON - Cli Number Should Equal    ${after}    inputInterval    ${old}",
            ],
        ),
    ],
)

S(
    "ASC-018",
    sheet="ASC",
    area=INTERVAL,
    comment="The SP DS rounds run at the configured interval",
    doc="Verify that the SP DS rounds run at the configured interval "
        "(User Guide 10.4).",
    cases=[
        C(
            "Read the SP DS interval and change it",
            doc=[
                "Step 1. Read the output interval of the ASC",
                "Step 2. Set it to 900 s and read it back",
            ],
            tags=["CLI", "WRITE"],
            log="1_interval.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    outputInterval",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config outputInterval 900",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "IT COMMON - Cli Number Should Equal    ${after}    outputInterval    900",
            ],
        ),
        C(
            "Put the original interval back",
            doc=[
                "Step 1. Put the output interval back",
                "Step 2. Read the configuration",
            ],
            tags=["CLI", "WRITE"],
            log="2_restore.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    outputInterval",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config outputInterval ${old}",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "IT COMMON - Cli Number Should Equal    ${after}    outputInterval    ${old}",
            ],
        ),
    ],
)

S(
    "ASC-019",
    sheet="ASC",
    area=INTERVAL,
    comment="The RF board is committed at the notify interval",
    doc="Verify the periodic RF commit (User Guide 10.4).",
    cases=[
        C(
            "Read the RF board notify interval of the AGC",
            doc=[
                "Step 1. Read the notify interval of the AGC configuration",
                "Step 2. Set it to 900 s and read it back",
            ],
            tags=["CLI", "WRITE"],
            log="1_notify.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    Rfboard notify interval",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 11 900",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${after}",
                "IT COMMON - Cli Number Should Equal    ${after}    Rfboard notify interval    900",
            ],
        ),
        C(
            "Put the original notify interval back",
            doc=[
                "Step 1. Read the original notify interval",
                "Step 2. Put it back and read the configuration",
            ],
            tags=["CLI", "WRITE"],
            log="2_restore.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    Rfboard notify interval",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 11 ${old}",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "IT COMMON - Cli Number Should Equal    ${after}    Rfboard notify interval    ${old}",
            ],
        ),
    ],
)

S(
    "ASC-020",
    bench=True,
    sheet="ASC",
    area=TELEMETRY,
    comment="The telemetry is persisted at the persist interval",
    doc="Verify that the telemetry is persisted periodically and once more at "
        "shutdown (User Guide 10.4).",
    cases=[
        C(
            "Verify periodic and shutdown telemetry persistence",
            doc=[
                "Step 1. Save the original interval, set it to 60 s and restart sc-asc",
                "Step 2. Verify a periodic write and a write during service restart",
                "Step 3. Restore the original interval",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_persist.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    Telemetry persist interval",
                "VAR    ${path}    /mnt/sc_nonvol/agc_telemetry_data.json",
                "TRY",
                "    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 15 60",
                "    Should Contain    ${set}    set_agc_config...success",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - Telemetry Interval Should Equal    60",
                "    ${restart}=    IT COMMON - Run Dut Root Command And Return    systemctl restart sc-asc && echo SC_ASC_RESTART_OK    timeout=120",
                "    Should Contain    ${restart}    SC_ASC_RESTART_OK",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - Telemetry Interval Should Equal    60",
                "    ${initial}=    IT COMMON - Run Dut Root Command And Return    stat -c %Y ${path}",
                "    Should Match Regexp    ${initial.strip()}    ^[0-9]+$",
                "    ${cursor}=    IT COMMON - Read Journal Cursor",
                "    VAR    ${journal_cmd}    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'",
                "    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    Scheduled telemetry persistence completed    timeout=150    interval=5",
                "    ${periodic}=    IT COMMON - Run Dut Root Command And Return    stat -c %Y ${path}",
                "    Should Be True    int($periodic.strip()) > int($initial.strip())    msg=Telemetry file was not updated periodically",
                "    Sleep    2s",
                "    ${cursor}=    IT COMMON - Read Journal Cursor",
                "    ${restart}=    IT COMMON - Run Dut Root Command And Return    systemctl restart sc-asc && echo SC_ASC_RESTART_OK    timeout=120",
                "    Should Contain    ${restart}    SC_ASC_RESTART_OK",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active",
                "    ${shutdown}=    IT COMMON - Run Dut Root Command And Return    stat -c %Y ${path}",
                "    Should Be True    int($shutdown.strip()) > int($periodic.strip())    msg=Telemetry file was not written at shutdown",
                "    ${journal}=    IT COMMON - Run Dut Root Command And Return    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'",
                "    Should Contain    ${journal}    Saving telemetry data during shutdown",
                "FINALLY",
                "    SSH_IT_ROOT.Close",
                "    SSH_IT_ROOT.Connect    ssh_setting=${SSH_DUT_IT}    level=ROOT    main_log_name=${case_name}-ssh_root.log",
                "    ${active}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Root Command And Return    systemctl is-active sc-asc",
                "    IF    $active is not None and $active.strip() == 'inactive'",
                "        Run Keyword And Continue On Failure    IT COMMON - Run Dut Root Command And Return    systemctl start sc-asc    timeout=120",
                "    END",
                "    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active",
                "    ${restored}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 15 ${old}",
                "    Run Keyword And Continue On Failure    Should Contain    ${restored}    set_agc_config...success",
                "    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Telemetry Interval Should Equal    ${old}",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-021",
    sheet="ASC",
    area=TEMP_COMP,
    comment="The legacy US temperature compensation follows the eCM tracking flag",
    doc="Verify that the legacy US temperature compensation process is "
        "controlled by the eCM track flag (User Guide 10.4).",
    cases=[
        C(
            "Read the eCM tracking flag of the AGC",
            doc=[
                "Step 1. Read the eCM tracking flag",
                "Step 2. Read the NP US state machine",
            ],
            tags=["CLI"],
            log="1_temp_comp.log",
            body=[
                "${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${track}=    IT COMMON - Get Cli Field    ${agc}    Track eCM power enable",
                "Log    ${track}",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us",
                "Log    ${status}",
            ],
        ),
    ],
)

S(
    "ASC-023",
    sheet="ASC",
    area=TELEMETRY,
    comment="The telemetry entries are generated and persisted",
    doc="Verify that the telemetry entries are generated and persisted "
        "(User Guide 10.4).",
    cases=[
        C(
            "Check the telemetry file and the telemetry over gNMI",
            doc=[
                "Step 1. Check that /mnt/sc_nonvol/agc_telemetry_data.json exists and parses",
                "Step 2. Read the telemetry over gNMI",
            ],
            tags=["FILE", "GNMI"],
            log="1_telemetry.log",
            body=[
                "${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/agc_telemetry_data.json    timeout=60",
                "Should Not Be Equal    ${size}    0",
                "${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/agc_telemetry_data.json",
                "Should Not Be Equal    ${parsed}    ${EMPTY}",
            ],
        ),
    ],
)

S(
    "ASC-026",
    sheet="ASC",
    area=CLIPPING,
    comment="The NP clipping events are detected and reported",
    doc="Verify that the NP clipping events are detected and reported "
        "(User Guide 10.4). The overload signal is injected with the bench.",
    cases=[
        C(
            "Read the clipping state and the clip counter",
            doc=[
                "Step 1. Read the clipping interval of the ASC",
                "Step 2. Read the clipping state machine",
                "Step 3. Read the clip counter of the north port",
            ],
            tags=["CLI"],
            log="1_clipping.log",
            body=[
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${interval}=    IT COMMON - Get Cli Field    ${config}    clippingInterval",
                "Log    ${interval}",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status clipping",
                "Log    ${status}",
                "${fsm}=    IT COMMON - Get Cli Field    ${status}    fsm",
                "Should Be Equal    ${fsm}    Clipping",
                "${port}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_port_status 0",
                "${count}=    IT COMMON - Get Cli Field    ${port}    rx_adc_clip_count",
                "Log    ${count}",
            ],
        ),
    ],
)

S(
    "ASC-027",
    sheet="ASC",
    area=CLIPPING,
    comment="The near clipping guardrail of the NP port",
    doc="Verify the near-clipping warning threshold and the guardrail "
        "configuration (User Guide 10.4).",
    cases=[
        C(
            "Read the clipping guardrail of the AGC and change it",
            doc=[
                "Step 1. Read the NP clipping guardrail",
                "Step 2. Set it to 3 dB and read it back",
                "Step 3. Put it back",
            ],
            tags=["CLI", "WRITE"],
            log="1_guardrail.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    NP Clipping Guardrail",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 9 3",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${after}",
                "IT COMMON - Cli Number Should Equal    ${after}    NP Clipping Guardrail    3",
                "${back}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 9 ${old}",
                "${restored}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "IT COMMON - Cli Number Should Equal    ${restored}    NP Clipping Guardrail    ${old}",
            ],
        ),
    ],
)

S(
    "ASC-028",
    bench=True,
    sheet="ASC",
    area=CONTROL,
    comment="Start and stop the control loops by hand",
    doc="Verify the manual start and stop control of the loops (User Guide 10.4).",
    cases=[
        C(
            "Stop and start the control loops",
            doc=[
                "Step 1. Stop the loops while NP DS is running",
                "Step 2. Check all four loops stay stopped for an input interval",
                "Step 3. Start the loops and verify NP DS runs again",
                "Step 4. Disable ASC and verify stop and start are refused",
                "Step 5. Restore the original mode and control state",
            ],
            tags=["CLI", "WRITE"],
            log="1_control.log",
            body=[
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode",
                "Should Be Equal    ${mode}    FreeRun    msg=This test requires FreeRun",
                "${interval}=    IT COMMON - Get Cli Field    ${config}    inputInterval",
                "Should Be True    int($interval) > 0    msg=Invalid NP DS interval",
                "IT ASC - All FSMs Should Have State    true",
                "VAR    ${stop_attempted}    ${FALSE}",
                "TRY",
                "    Wait Until Keyword Succeeds    600s    1s    IT ASC - NP DS Should Be Running",
                "    ${cursor}=    IT COMMON - Read Journal Cursor",
                "    VAR    ${stop_attempted}    ${TRUE}",
                "    ${stop}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control stop",
                "    Should Contain    ${stop}    set_agc_control success",
                "    Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    false    ${TRUE}",
                "    VAR    ${journal_cmd}    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'",
                "    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    Control loops stopping    timeout=30    interval=2",
                "    ${stopped_at}=    Evaluate    time.monotonic()    modules=time",
                "    WHILE    time.monotonic() - $stopped_at < int($interval) + 5",
                "        IT ASC - All FSMs Should Have State    false    ${TRUE}",
                "        Sleep    5s",
                "    END",
                "    ${start}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start",
                "    Should Contain    ${start}    set_agc_control success",
                "    VAR    ${stop_attempted}    ${FALSE}",
                "    Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    true",
                "    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    Control loops starting    timeout=30    interval=2",
                "    Wait Until Keyword Succeeds    600s    1s    IT ASC - NP DS Should Be Running",
                "    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0",
                "    Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    false    ${TRUE}",
                "    ${disabled_stop}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control stop",
                "    Should Contain    ${disabled_stop}    set_agc_control failed",
                "    ${disabled_start}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start",
                "    Should Contain    ${disabled_start}    set_agc_control failed",
                "FINALLY",
                "    Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}",
                "    IF    $stop_attempted",
                "        ${restore}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start",
                "        Run Keyword And Continue On Failure    Should Contain    ${restore}    set_agc_control success",
                "    END",
                "    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    true",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-029",
    bench=True,
    sheet="ASC",
    area=CONTROL,
    comment="The ADU status follows the operation mode",
    doc="Verify that the ADU status reflects the operation mode and the "
        "guardrail latches (User Guide 10.4). Skipped until external north port "
        "signal control is implemented and validated.",
    cases=[
        C(
            "Check ADU status across operation modes and an out-of-range event",
            doc=[
                "Step 1. Check OFF in Disable and Monitor",
                "Step 2. Check TRACKING in FreeRun",
                "Step 3. Trigger an out-of-range event and check ON_HOLD",
                "Step 4. Restore the signal and check TRACKING resumes",
                "Step 5. Restore the original mode",
            ],
            tags=["CLI", "WRITE", "MANUAL_BENCH", "robot:skip"],
            log="1_adu.log",
            body=[
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode",
                "${snapshot}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "${end_freq}=    IT COMMON - Get Cli Field    ${snapshot}    ds_end_frequency_hz",
                "Should Be True    int($end_freq.split()[0]) > 0    msg=Calibration snapshot is missing",
                "VAR    ${external_attempted}    ${FALSE}",
                "TRY",
                "    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0",
                "    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "    IT COMMON - Cli Field Should Equal    ${config}    operationMode    Disable",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - ADU State Should Be    OFF",
                "    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 2",
                "    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "    IT COMMON - Cli Field Should Equal    ${config}    operationMode    Monitor",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - ADU State Should Be    OFF",
                "    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "    IT COMMON - Cli Field Should Equal    ${config}    operationMode    FreeRun",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - ADU State Should Be    TRACKING",
                "    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle",
                "    VAR    ${external_attempted}    ${TRUE}",
                "    IT ASC EXTERNAL - Set North Port Input Delta    -6",
                "    Wait Until Keyword Succeeds    600s    5s    IT ASC - ADU State Should Be    ON_HOLD",
                "    IT ASC EXTERNAL - Restore North Port Signal",
                "    VAR    ${external_attempted}    ${FALSE}",
                "    Wait Until Keyword Succeeds    600s    5s    IT ASC - ADU State Should Be    TRACKING",
                "FINALLY",
                "    IF    $external_attempted",
                "        Run Keyword And Continue On Failure    IT ASC EXTERNAL - Restore North Port Signal",
                "    END",
                "    Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-030",
    bench=True,
    sheet="ASC",
    area=CONTROL,
    comment="The FSM status query reports the state of the loops",
    doc="Verify that get_asc_fsm_status reports the loop state (User Guide 10.4).",
    cases=[
        C(
            "Check FSM status while enabled, running and disabled",
            doc=[
                "Step 1. Validate all four FSM status responses",
                "Step 2. Observe an in-flight NP DS round and its completed count",
                "Step 3. Disable ASC and verify all FSMs are disabled",
                "Step 4. Restore the original mode",
            ],
            tags=["CLI", "WRITE"],
            log="1_fsm.log",
            vars=[("fsms", {"np_ds": "NpDs", "sp_ds": "SpDs",
                            "np_us": "NpUs", "clipping": "Clipping"})],
            body=[
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode",
                "Should Be Equal    ${mode}    FreeRun    msg=This test requires FreeRun",
                "FOR    ${fsm}    ${name}    IN    &{fsms}",
                "    IT ASC - FSM Status Should Be Valid    ${fsm}    ${name}    true",
                "END",
                "Wait Until Keyword Succeeds    180s    2s    IT ASC - NP DS Should Be Idle",
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds",
                "${before_count}=    IT COMMON - Get Cli Field    ${before}    loop_count",
                "TRY",
                "    ${inflight}=    Wait Until Keyword Succeeds    600s    1s    IT ASC - NP DS Should Be Running",
                "    ${stage}=    IT COMMON - Get Cli Field    ${inflight}    current_stage",
                "    Should Not Be Equal    ${stage}    Idle",
                "    Wait Until Keyword Succeeds    180s    2s    IT ASC - NP DS Should Be Idle",
                "    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds",
                "    ${after_count}=    IT COMMON - Get Cli Field    ${after}    loop_count",
                "    Run Keyword And Continue On Failure    Should Be True    int($after_count) > int($before_count)    msg=NP DS loop_count did not accumulate after a completed round (${before_count} -> ${after_count})",
                "    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0",
                "    Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    false    ${TRUE}",
                "    FOR    ${fsm}    ${name}    IN    &{fsms}",
                "        IT ASC - FSM Status Should Be Valid    ${fsm}    ${name}    false",
                "    END",
                "FINALLY",
                "    Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}",
                "    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    true",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-031",
    sheet="ASC",
    area=GATING,
    comment="The ASC rounds do not start while the MGC holds the RF board",
    doc="Verify that the ASC rounds do not start while the MGC controller "
        "preempts the right to use the RF board (User Guide 10.4).",
    cases=[
        C(
            "Read the MSC controller and the bypass decision",
            doc=[
                "Step 1. Read the MSC state and the MSC controller",
                "Step 2. Read the bypass controller decision",
            ],
            tags=["CLI"],
            log="1_msc.log",
            body=[
                "${state}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_state",
                "${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller",
                "${bypass}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_bypass_controller_decision",
                "Log    ${state}",
                "Log    ${controller}",
                "Log    ${bypass}",
                "Should Contain    ${state}    MSC state:",
                "Should Contain    ${controller}    MSC controller:",
                "Should Contain    ${bypass}    Bypass controller decision:",
            ],
        ),
        C(
            "Hold the RF board with the MSC controller and read the ASC",
            doc=[
                "Step 1. Hand the RF board over to the ASC controller (index 3)",
                "Step 2. Read the ASC configuration and the state machines",
                "Step 3. Give the RF board back to nobody (index 0)",
            ],
            tags=["CLI", "WRITE"],
            log="2_preempt.log",
            body=[
                "${set}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_msc_controller 3",
                "${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller",
                "Log    ${controller}",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds",
                "Log    ${status}",
                "${release}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_msc_controller 0",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller",
                "Log    ${after}",
            ],
        ),
    ],
)

S(
    "ASC-032",
    sheet="ASC",
    area=GATING,
    comment="The loops stay stopped until the PAB is over",
    doc="Verify that the loops stay stopped until the PAB completes "
        "(User Guide 10.4).",
    cases=[
        C(
            "Stop the PAB and read the ASC",
            doc=[
                "Step 1. Stop the PAB",
                "Step 2. Read the PAB status",
                "Step 3. Read the state of the four state machines",
            ],
            tags=["CLI", "WRITE"],
            log="1_pab_gate.log",
            body=[
                "${stop}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control stop",
                "${pab}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                "Log    ${pab}",
            ] + [
                "${%s}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status %s" % (fsm, fsm)
                for fsm in FSMS
            ] + [
                "FOR    ${fsm}    IN    @{fsms}",
                "    ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled",
                "    Log    ${state}",
                "END",
            ],
            vars=[("fsms", FSMS)],
        ),
        C(
            "Start the PAB again",
            doc=[
                "Step 1. Start the PAB in FreeRun mode",
                "Step 2. Read the PAB status",
            ],
            tags=["CLI", "WRITE"],
            log="2_pab_start.log",
            body=[
                "${run}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control free_run",
                "Should Contain    ${run}    Success",
                "${pab}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                "Log    ${pab}",
            ],
        ),
    ],
)

S(
    "ASC-033",
    sheet="ASC",
    area=GATING,
    comment="The loops stop during the calibration and resume after it",
    doc="Verify that the loops stop during the calibration and resume after "
        "the calibration data store (User Guide 10.4).",
    cases=[
        C(
            "Raise the calibration required flag and read the ASC",
            doc=[
                "Step 1. Read the calibration required flag",
                "Step 2. Raise it",
                "Step 3. Read the state of the four state machines",
                "Step 4. Clear the flag again",
            ],
            tags=["CLI", "WRITE"],
            log="1_calibration_gate.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag",
                "Log    ${before}",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_calib_req_config_flag true",
            ] + [
                "${%s}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status %s" % (fsm, fsm)
                for fsm in FSMS
            ] + [
                "FOR    ${fsm}    IN    @{fsms}",
                "    ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled",
                "    Log    ${state}",
                "END",
                "${clear}=    IT COMMON - Run Dut Command And Return    sc_cli set_calib_req_config_flag false",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag",
                "Should Contain    ${after}    flag: false",
            ],
            vars=[("fsms", FSMS)],
        ),
    ],
)

S(
    "ASC-034",
    sheet="ASC",
    area=ROBUSTNESS,
    comment="The configuration and the snapshot survive a restart of the daemon",
    doc="Verify that the configuration and the snapshot survive a restart of "
        "the sc-asc daemon (User Guide 10.4).",
    cases=[
        C(
            "Read the configuration before the restart",
            doc=[
                "Step 1. Read the ASC and the AGC configuration",
                "Step 2. Restart the sc-asc daemon",
                "Step 3. Read the configuration again, it has to be the same",
            ],
            tags=["CLI", "WRITE"],
            log="1_restart.log",
            body=[
                "${asc_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${agc_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${restart}=    IT COMMON - Run Dut Command And Return    systemctl restart sc-asc    timeout=60",
                "Log    ${restart}",
                "Sleep    10",
                "${asc_after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${agc_after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${asc_after}",
                "Should Be Equal    ${asc_after}    ${asc_before}",
                "Should Be Equal    ${agc_after}    ${agc_before}",
            ],
        ),
    ],
)

S(
    "ASC-035",
    sheet="ASC",
    area=ROBUSTNESS,
    comment="The daemon recovers from a corrupted agc_data.json",
    doc="Verify the recovery from a corrupted agc_data.json (User Guide 10.4).",
    cases=[
        C(
            "Corrupt the configuration file and restart the daemon",
            doc=[
                "Step 1. Back up /mnt/sc_nonvol/agc_data.json",
                "Step 2. Overwrite it with something that is not JSON",
                "Step 3. Restart the sc-asc daemon",
                "Step 4. Check that the daemon runs and that the configuration is back",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_corrupt.log",
            body=[
                "${backup}=    IT COMMON - Run Dut Command And Return    cp /mnt/sc_nonvol/agc_data.json /tmp/agc_data_backup.json",
                "${break}=    IT COMMON - Run Dut Command And Return    echo 'this is not json' > /mnt/sc_nonvol/agc_data.json",
                "${restart}=    IT COMMON - Run Dut Command And Return    systemctl restart sc-asc    timeout=60",
                "Log    ${restart}",
                "${status}=    IT COMMON - Wait For Dut Command Contains    systemctl is-active sc-asc    active    timeout=60",
                "Log    ${status}",
                "Should Contain    ${status}    active",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${config}",
                "${restore}=    IT COMMON - Run Dut Command And Return    cp /tmp/agc_data_backup.json /mnt/sc_nonvol/agc_data.json",
            ],
        ),
    ],
)

S(
    "ASC-036",
    sheet="ASC",
    area=ROBUSTNESS,
    comment="The AMP recovers from a corrupted agc_data.json after a power off",
    doc="Verify the recovery from a corrupted agc_data.json when the AMP is "
        "powered off and on again (User Guide 10.4). The power off is a step of "
        "the bench procedure.",
    cases=[
        C(
            "Corrupt the configuration file",
            doc=[
                "Step 1. Back up /mnt/sc_nonvol/agc_data.json",
                "Step 2. Overwrite it with something that is not JSON",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_corrupt.log",
            body=[
                "${backup}=    IT COMMON - Run Dut Command And Return    cp /mnt/sc_nonvol/agc_data.json /tmp/agc_data_backup.json",
                "${break}=    IT COMMON - Run Dut Command And Return    echo 'this is not json' > /mnt/sc_nonvol/agc_data.json",
                "${check}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/agc_data.json",
                "Log    ${check}",
                # The power off that the template asks for is a step of the bench",
                # procedure, so the file is put back here.",
                "${restore}=    IT COMMON - Run Dut Command And Return    cp /tmp/agc_data_backup.json /mnt/sc_nonvol/agc_data.json",
                "${after}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/agc_data.json",
                "Log    ${after}",
                "Should Not Contain    ${after}    this is not json",
            ],
        ),
    ],
)

S(
    "ASC-037",
    sheet="ASC",
    area=ROBUSTNESS,
    comment="The ASC runs without a calibration snapshot",
    doc="Verify the behaviour of the ASC when the calibration snapshot is "
        "lost (User Guide 10.4).",
    cases=[
        C(
            "Remove the calibration snapshot and restart the daemon",
            doc=[
                "Step 1. Remove /mnt/sc_nonvol/asc_calib_snapshot.json",
                "Step 2. Restart the sc-asc daemon",
                "Step 3. Check that the daemon runs",
                "Step 4. Read the ASC configuration",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_snapshot_lost.log",
            body=[
                                # The snapshot is only there when a calibration was run before.
                # The point of the case is that the ASC runs without it, so the
                # case works either way: it removes the snapshot if there is
                # one and puts it back afterwards.
                "${before}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol/asc_calib_snapshot.json",
                "Log    ${before}",
                "${existed}=    Evaluate    'No such file' not in $before    modules=builtins",
                "IF    $existed",
                "    ${backup}=    IT COMMON - Run Dut Command And Return    cp /mnt/sc_nonvol/asc_calib_snapshot.json /tmp/asc_calib_snapshot.backup",
                "    ${remove}=    IT COMMON - Run Dut Command And Return    rm -f /mnt/sc_nonvol/asc_calib_snapshot.json",
                "END",
                "${restart}=    IT COMMON - Run Dut Command And Return    systemctl restart sc-asc    timeout=60",
                "Log    ${restart}",
                "${status}=    IT COMMON - Wait For Dut Command Contains    systemctl is-active sc-asc    active    timeout=60",
                "Should Contain    ${status}    active",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Log    ${config}",
                "IF    $existed",
                # The snapshot is put back, so that the ASC keeps the
                # reference spectrum of the calibration.
                "    ${restore}=    IT COMMON - Run Dut Command And Return    cp /tmp/asc_calib_snapshot.backup /mnt/sc_nonvol/asc_calib_snapshot.json",
                "    ${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/asc_calib_snapshot.json    timeout=60",
                "    Should Not Be Equal    ${size}    0",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-038",
    bench=True,
    sheet="ASC",
    area=GRPC_CONFIG,
    comment="Read and set the ASC configuration over gRPC",
    doc="Use grpcurl to GET and SET the ASC configuration through the gRPC "
        "AscConfigService, then verify the values with sc_cli get_asc_config "
        "(User Guide 12.1.1).",
    vars=[
        ("proto", "asc_config.proto"),
        ("get_method", "gnoi.asc_config.v1.AscConfigService/GetAscConfiguration"),
        ("set_method", "gnoi.asc_config.v1.AscConfigService/SetAscConfiguration"),
    ],
    cases=[
        C(
            "SET the ASC configuration over gRPC and read it back",
            doc=[
                "Step 1. Save all eleven original fields",
                "Step 2. Set the template configuration over gRPC",
                "Step 3. Compare every field through gRPC and sc_cli",
                "Step 4. Restore and verify all original fields",
            ],
            tags=["GRPC", "CLI", "WRITE"],
            log="2_set.log",
            vars=[
                ("payload", '{"ascConfig": {"enable": 1, "inputInterval": 120, '
                            '"outputInterval": 600, "clippingInterval": 1, '
                            '"inputPowerTransientThreshold": 0.5, "deltaPilotDiffThreshold": 0.7, '
                            '"maxPositiveAdjustment": 4.0, "maxNegativeAdjustment": -4.0, '
                            '"firstPilotFrequency": 261000000, "secondPilotFrequency": 711000000, '
                            '"thirdPilotFrequency": 903000000}}'),
            ],
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "${original}=    IT COMMON - Grpc Get Field    ${response}    ascConfig",
                "IT ASC - Grpc And CLI Configuration Should Equal    ${original}",
                "${restore_payload}=    Evaluate    json.dumps({'ascConfig': $original})    modules=json",
                "${expected}=    Evaluate    json.loads($payload)['ascConfig']    modules=json",
                "TRY",
                "    ${set}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${payload}",
                "    IT COMMON - Grpc Should Succeed    ${set}",
                "    Wait Until Keyword Succeeds    120s    5s    IT ASC - Grpc And CLI Configuration Should Equal    ${expected}",
                "FINALLY",
                "    ${restore}=    Run Keyword And Continue On Failure    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${restore_payload}",
                "    Run Keyword And Continue On Failure    IT COMMON - Grpc Should Succeed    ${restore}",
                "    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Grpc And CLI Configuration Should Equal    ${original}",
                "END",
            ],
        ),
    ],
)

S(
    "ASC-039",
    sheet="ASC",
    area=AGC_FDX,
    comment="The AGC with the FDX enablement workaround",
    doc="Verify the User Guide 8.6 workaround for the AGC test with the FDX "
        "enablement: disable the ASC, do the FDX enablement, trigger the AGC "
        "baseline store with calib_us_legacy, reboot and enable the ASC again "
        "(User Guide 8.6). The FDX enablement and the reboot are steps of the "
        "bench procedure.",
    cases=[
        C(
            "Disable the ASC",
            doc=[
                "Step 1. Set the operation mode to Disable",
                "Step 2. Read the ASC configuration",
            ],
            tags=["CLI", "WRITE"],
            log="1_disable.log",
            body=[
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Log    ${config}",
                "Should Contain    ${config}    operationMode = Disable",
            ],
        ),
        C(
            "Trigger the AGC baseline store",
            doc=[
                "Step 1. Run sc_cli calib_us_legacy",
                "Step 2. Check that the calibration succeeded",
            ],
            tags=["CLI", "WRITE"],
            log="2_baseline.log",
            body=[
                # The command asks the MSC for the amplifier and the PAB
                # service holds it now and then, so it is run again until the
                # amplifier is free.
                "${calib}=    IT COMMON - Run Dut Command Until Not Refused    sc_cli calib_us_legacy    Failed to request ALN control from MSC    timeout=600    interval=15    cmd_timeout=120",
                "Log    ${calib}",
                "Should Contain    ${calib}    success",
            ],
        ),
        C(
            "Enable the ASC again",
            doc=[
                "Step 1. Set the operation mode to FreeRun",
                "Step 2. Read the ASC configuration",
            ],
            tags=["CLI", "WRITE"],
            log="3_enable.log",
            body=[
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Log    ${config}",
                "Should Contain    ${config}    operationMode = FreeRun",
            ],
        ),
    ],
)
