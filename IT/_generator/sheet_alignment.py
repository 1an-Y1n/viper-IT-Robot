"""The ALIGNMENT sheet of the LE IT test template: ALN-001 to ALN-015.

The alignment flows (ALN-002 to ALN-006) configure the DUT the way the
template prescribes and leave it that way, which is what the bench is for.
The flows that reboot the DUT say so in their documentation: the reboot is a
step of the bench procedure, not something a suite does on its own.
"""

from writer import C, S, SUITES

CLI_CAL = "Sercomm CLI Calibration"
FDX_ALIGN = "FDX & Non-FDX Alignment"
LEGACY_US = "Legacy US Calibration Error Factory Compensation"
CLISH_CAL = "CLISH Calibration Modes"
GNMI_ALIGN = "GNMI Alignment (DS1 / DS2 / DS3 / US)"
GRPC_CAL = "GRPC Calibration Service"
CONTROL_FLAGS = "Calibration Control Flags"

# The five alignment types of the gNMI amp-alignment tree.
ALIGNMENT_TYPES = [
    "ALIGN_DOWNSTREAM_STAGE_1",
    "ALIGN_DOWNSTREAM_STAGE_2",
    "ALIGN_DOWNSTREAM_STAGE_3",
    "ALIGN_UPSTREAM",
    "ALIGN_NETWORK",
]

# The states the alignment-status leaf may carry.
ALIGNMENT_STATUSES = [
    "ALIGN_STATUS_UNALIGNED",
    "ALIGN_STATUS_IN_PROGRESS",
    "ALIGN_STATUS_ALIGNED",
    "ALIGN_STATUS_FAILURE",
]

# The LNA mode of the PAB and the name the CLI prints behind the number
# (sc_cli_api.c: INVALID, FROZEN, FREE_RUNNING, FIXED_GAIN).
LNA_MODE_NAMES = {
    "1": "FROZEN",
    "2": "FREE_RUNNING",
    "3": "FIXED_GAIN",
}


def _ds_profile_case(item_id, port, profile, start_freq, start_power, end_freq, end_power):
    """Configure the ds-profile of one port through the clish view."""
    view = "ds-profile-%s" % port
    return C(
        "Configure the %s port ds-profile" % port,
        doc=[
            "Step 1. Enter the ds-profile view of the %s port" % port,
            "Step 2. Set the name and the frequency / power range",
            "Step 3. Show the configuration and commit it",
            "Step 4. Leave the view",
        ],
        tags=["CLI", "WRITE"],
        log="%s_ds_profile.log" % port,
        body=[
            "${enter}=    IT COMMON - Fdx Enter View    configure ds-profile %s    %s" % (port, view),
            "${name}=    IT COMMON - Run Fdx View Command And Return    %s    name %s" % (view, profile),
            "${start_freq}=    IT COMMON - Run Fdx View Command And Return    %s    start-freq %s" % (view, start_freq),
            "${start_power}=    IT COMMON - Run Fdx View Command And Return    %s    start-power %s" % (view, start_power),
            "${end_freq}=    IT COMMON - Run Fdx View Command And Return    %s    end-freq %s" % (view, end_freq),
            "${end_power}=    IT COMMON - Run Fdx View Command And Return    %s    end-power %s" % (view, end_power),
            "${step}=    IT COMMON - Run Fdx View Command And Return    %s    step-down 0 start-freq 1002000000" % view,
            "${size}=    IT COMMON - Run Fdx View Command And Return    %s    step-down 0 size-db 0.0" % view,
            "${before}=    IT COMMON - Run Fdx View Command And Return    %s    show configuration" % view,
            "${commit}=    IT COMMON - Run Fdx View Command And Return    %s    commit" % view,
            "Should Contain    ${commit}    applied local configuration",
            "${after}=    IT COMMON - Run Fdx View Command And Return    %s    show configuration" % view,
            "${exit}=    IT COMMON - Fdx Exit View    %s" % view,
            "${actual_name}=    IT COMMON - Get Clish Field    ${after}    name",
            "Should Be Equal    ${actual_name}    %s" % profile,
            "IT COMMON - Clish Number Should Equal    ${after}    start-freq    %s" % start_freq,
            "IT COMMON - Clish Number Should Equal    ${after}    start-power    %s" % start_power,
            "IT COMMON - Clish Number Should Equal    ${after}    end-freq    %s" % end_freq,
            "IT COMMON - Clish Number Should Equal    ${after}    end-power    %s" % end_power,
            "IT COMMON - Clish Number Should Equal    ${after}    step-index:0 start-freq    1002000000",
            "IT COMMON - Clish Number Should Equal    ${after}    step-index:0 size-db    0",
        ],
    )


def _pab_case(item_id, lna_mode, target_tcp, rpd_threshold):
    """Set the PAB configuration and run one FreeRun round."""
    return C(
        "Run the PAB FreeRun round",
        doc=[
            "Step 1. Set the PAB configuration",
            "Step 2. GET the configuration back",
            "Step 3. Stop the PAB and start it again in FreeRun",
            "Step 4. Wait until the round is over",
            "Step 5. Check that the eCM is operational",
        ],
        tags=["CLI", "WRITE"],
        log="pab.log",
        vars=[
            ("lna_mode", lna_mode),
            ("lna_mode_name", LNA_MODE_NAMES[lna_mode]),
            ("target_tcp", target_tcp),
            ("rpd_threshold", rpd_threshold),
        ],
        body=[
            "${set_cmd}=    Catenate    SEPARATOR=${SPACE}    sc_cli set_pab_config    ${lna_mode}    2.74    ${target_tcp}    60    60    ${rpd_threshold}    6",
            "${set_out}=    IT COMMON - Run Dut Command And Return    ${set_cmd}    timeout=30",
            "Log    ${set_out}",
            "Should Contain    ${set_out}    Success",
            "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config",
            "${mode}=    IT COMMON - Get Cli Field    ${config}    rx adc lna mode",
            # The name behind the number depends on the mode: the Full FDX
            # lineup runs with mode 3 (FIXED_GAIN), the Non-FDX ones with
            # mode 2 (FREE_RUNNING).
            "Should Be Equal    ${mode}    ${lna_mode} (${lna_mode_name})",
            # The CLI prints the numbers with two decimals ("29.00 dBmV"),
            # so they are compared as numbers and not as text.
            "IT COMMON - Cli Number Should Equal    ${config}    target tcp    ${target_tcp}",
            "IT COMMON - Cli Number Should Equal    ${config}    rx adc lna gain    2.74",
            "IT COMMON - Cli Number Should Equal    ${config}    RPD power threshold    ${rpd_threshold}",
            "${stop}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control stop",
            "Should Contain    ${stop}    Success",
            "${run}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control free_run",
            "Should Contain    ${run}    Success",
            "${fields}=    Create List    Running Mode=FREERUN    Completed=Yes    Current Stage=IDLE",
            "${status}=    IT COMMON - Wait For Dut Cli Fields    sc_cli get_pab_status    ${fields}    timeout=300    interval=10",
            "Log    ${status}",
            # The eCM walks through a series of states before it is operational:
            # RangeStart -> StartDsAcquisition -> StartUsAcquisition ->
            # RangeStart -> Operational. Measured: 4m43s after the PAB
            # FreeRun was over on one bench unit, 3m29s after the reboot on
            # another one. The window has to be wide enough for that.
            "${ecm}=    IT COMMON - Wait For Dut Command Contains    sc_amphal_cli get_ecm_status    eCM status = Operational    timeout=600    interval=10",
            "Log    ${ecm}",
        ],
    )


def _alignment_stages_case(item_id, stages, view="alignment"):
    """Run the alignment stages and check the status."""
    body = []
    for stage in stages:
        body.append(
            "${%s}=    IT COMMON - Run Fdx View Command And Return    %s    start-%s"
            "    timeout=300" % (stage, view, stage)
        )
        body.append("Should Contain    ${%s}    Completed %s alignment" % (stage, stage.upper()))
    body.append("${status}=    IT COMMON - Run Fdx View Command And Return    %s    show alignment-status" % view)
    body.append("Log    ${status}")
    # "UNALIGNED" holds "ALIGNED" as a part of it, so the stage name has to
    # be in the assertion: "DS1:ALIGNED" is not in "DS1:UNALIGNED".
    for stage in stages:
        body.append(
            "Should Contain    ${status}    %s:ALIGNED"
            "    msg=the %s stage is not aligned, the answer was: ${status}"
            % (stage.upper(), stage.upper())
        )
    return C(
        "Run the alignment stages %s" % ", ".join(stages),
        doc=[
            "Step 1. Enter the alignment view",
            "Step 2. Run the stages in order: %s" % ", ".join(stages),
            "Step 3. Show the alignment status",
            "Step 4. Leave the view",
        ],
        tags=["CLI", "WRITE"],
        log="alignment_%s.log" % "_".join(stages),
        body=[
            "${enter}=    IT COMMON - Fdx Enter View    configure alignment    %s" % view,
        ] + body + [
            "${action}=    IT COMMON - Run Fdx View Command And Return    %s    show alignment-action" % view,
            "${exit}=    IT COMMON - Fdx Exit View    %s" % view,
            "Log    ${action}",
        ],
    )


def _spectrum_case(item_id, us_ext_start, us_ext_end, subband, exclusion=None):
    """Configure the spectrum allocation through the clish spectrum view.

    ``exclusion`` is the argument of the "add freq-exclusion" command, e.g.
    "383000000 396000000 PASS_OTHER EXCLUDED". The Partial FDX lineups need
    one, the others do not.
    """
    body = [
        "${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum",
        "${initial}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
        "${subband_count}=    IT COMMON - Get Count After Label    ${initial}    Total subbands",
        "Should Be True    $subband_count <= 3    Spectrum has more than three subbands; refusing to remove any.",
        "FOR    ${index}    IN RANGE    ${subband_count}",
        "    ${existing}=    IT COMMON - Get Clish Field    ${initial}    subBand:${index} mode",
        "END",
        "FOR    ${index}    IN RANGE    ${subband_count}    3",
        "    ${add}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband add %s" % subband,
        "    Should Contain    ${add}    successfully added mode %s" % subband,
        "END",
        "${prepared}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
        "IT COMMON - Clish Number Should Equal    ${prepared}    Total subbands    3",
        "FOR    ${index}    IN RANGE    3",
        "    ${existing}=    IT COMMON - Get Clish Field    ${prepared}    subBand:${index} mode",
        "END",
        "${ds_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-start-freq 108000000",
        "Should Contain    ${ds_start}    is set from",
        "${ds_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-end-freq 1218000000",
        "Should Contain    ${ds_end}    is set from",
        "${us_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-start-freq 5000000",
        "Should Contain    ${us_start}    is set from",
        "${us_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-end-freq 85000000",
        "Should Contain    ${us_end}    is set from",
        "${ext_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-start-freq %s" % us_ext_start,
        "Should Contain    ${ext_start}    is set from",
        "${ext_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-end-freq %s" % us_ext_end,
        "Should Contain    ${ext_end}    is set from",
        "${sub0}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 0 %s" % subband,
        "Should Contain    ${sub0}    is set from",
        "${sub1}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 1 %s" % subband,
        "Should Contain    ${sub1}    is set from",
        "${sub2}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 2 %s" % subband,
        "Should Contain    ${sub2}    is set from",
    ]
    if exclusion:
        # The frequency exclusions of the lineup that is on the DUT are
        # removed first, so that the allocation ends up with the exclusion
        # of the template and nothing else. The indices of the exclusions do
        # not shift when one of them is removed, so they are removed by
        # their original number.
        body.append(
            "${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration")
        body.append(
            "${exclusions}=    IT COMMON - Get Count After Label    ${before}"
            "    Total frequency exclusions")
        body.append("Log    ${before}")
        body.append("FOR    ${index}    IN RANGE    ${exclusions}")
        body.append(
            "    ${rm_excl}=    IT COMMON - Run Fdx View Command And Return"
            "    spectrum    remove freq-exclusion ${index}")
        body.append("    Should Contain    ${rm_excl}    successfully deleted")
        body.append("END")
        body.append(
            "${excl}=    IT COMMON - Run Fdx View Command And Return    spectrum"
            "    add freq-exclusion %s" % exclusion)
        body.append("Should Contain    ${excl}    successfully added")
    for output in ("staged", "after"):
        if output == "after":
            body += [
                "${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit    timeout=120",
                "Should Contain    ${commit}    applied local configuration",
            ]
        body += [
            "${%s}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration" % output,
            "IT COMMON - Clish Number Should Equal    ${%s}    ds-start-freq    108000000" % output,
            "IT COMMON - Clish Number Should Equal    ${%s}    ds-end-freq    1218000000" % output,
            "IT COMMON - Clish Number Should Equal    ${%s}    us-legacy-start-freq    5000000" % output,
            "IT COMMON - Clish Number Should Equal    ${%s}    us-legacy-end-freq    85000000" % output,
            "IT COMMON - Clish Number Should Equal    ${%s}    us-extended-start-freq    %s" % (output, us_ext_start),
            "IT COMMON - Clish Number Should Equal    ${%s}    us-extended-end-freq    %s" % (output, us_ext_end),
            "IT COMMON - Clish Number Should Equal    ${%s}    Total subbands    3" % output,
            "FOR    ${index}    IN RANGE    3",
            "    ${mode}=    IT COMMON - Get Clish Field    ${%s}    subBand:${index} mode" % output,
            "    Should Be Equal    ${mode}    \"%s\"" % subband,
            "END",
        ]
        if exclusion:
            body += [
                "IT COMMON - Clish Number Should Equal    ${%s}    Total frequency exclusions    1" % output,
                "IT COMMON - Clish Number Should Equal    ${%s}    Freq-Exclusion:0 start-hz    383000000" % output,
                "IT COMMON - Clish Number Should Equal    ${%s}    Freq-Exclusion:0 end-hz    396000000" % output,
                "${ds_type}=    IT COMMON - Get Clish Field    ${%s}    Freq-Exclusion:0 ds-fe-type" % output,
                "Should Be Equal    ${ds_type}    PASS_OTHER",
                "${us_type}=    IT COMMON - Get Clish Field    ${%s}    Freq-Exclusion:0 us-fe-type" % output,
                "Should Be Equal    ${us_type}    EXCLUDED",
            ]
    exit_view = "${exit}=    IT COMMON - Fdx Exit View    spectrum"
    body = body[:1] + ["TRY"] + ["    " + line for line in body[1:]] + [
        "FINALLY",
        "    " + exit_view,
        "END",
    ]
    doc = [
        "Step 1. Enter the spectrum view",
        "Step 2. Set the downstream, the legacy upstream and the extended upstream range",
        "Step 3. Add missing subbands if needed and set their modes",
        "Step 4. Show the configuration",
    ]
    if exclusion:
        doc.append("Step 5. Add the frequency exclusion")
    doc.append("Step 6. Commit it and leave the view")
    return C(
        "Configure the spectrum allocation",
        doc=doc,
        tags=["CLI", "WRITE"],
        log="spectrum.log",
        body=body,
    )


def _us_profile_rlsp_case(item_id):
    """Set the RLSP of the two us-profiles and of the two legacy ports.

    The FDX lineups need the RLSP of the FDX us-profiles as well; the
    Non-FDX ones only carry the legacy RLSP.
    """
    return C(
        "Set the RLSP of the us-profiles and of the legacy ports",
        doc=[
            "Step 1. Set the rlsp of the north and the south us-profile",
            "Step 2. Set the legacy rlsp of both ports",
        ],
        tags=["CLI", "WRITE"],
        log="us_profile.log",
        body=[
            "${enter_north}=    IT COMMON - Fdx Enter View    configure us-profile north    us-profile-north",
            "${rlsp_north}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    rlsp 8.0",
            "${commit_north}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    commit",
            "Should Contain    ${commit_north}    applied local configuration",
            "${after_north}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    show configuration",
            "${exit_north}=    IT COMMON - Fdx Exit View    us-profile-north",
            "${enter_south}=    IT COMMON - Fdx Enter View    configure us-profile south    us-profile-south",
            "${rlsp_south}=    IT COMMON - Run Fdx View Command And Return    us-profile-south    rlsp 8.0",
            "${commit_south}=    IT COMMON - Run Fdx View Command And Return    us-profile-south    commit",
            "Should Contain    ${commit_south}    applied local configuration",
            "${after_south}=    IT COMMON - Run Fdx View Command And Return    us-profile-south    show configuration",
            "${exit_south}=    IT COMMON - Fdx Exit View    us-profile-south",
            "${legacy_north}=    IT COMMON - Run Dut Command And Return    sc_cli set_legacy_rlsp north 8",
            "Should Contain    ${legacy_north}    Set legacy rlsp Success",
            "${legacy_south}=    IT COMMON - Run Dut Command And Return    sc_cli set_legacy_rlsp south 8",
            "Should Contain    ${legacy_south}    Set legacy rlsp Success",
            "IT COMMON - Clish Number Should Equal    ${after_north}    rlsp    8",
            "IT COMMON - Clish Number Should Equal    ${after_south}    rlsp    8",
            "${get_north}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp north",
            "${get_south}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp south",
            "IT COMMON - Cli Number Should Equal    ${get_north}    North Port rlsp    8",
            "IT COMMON - Cli Number Should Equal    ${get_south}    South Port rlsp    8",
        ],
    )


def _np_soc_target_tcp_case(item_id, value):
    """Set the NP SoC target TCP and read it back."""
    return C(
        "Set the NP SoC target TCP to %s dBmV" % value,
        doc=[
            "Step 1. Set the NP SoC target TCP to %s dBmV" % value,
            "Step 2. Read it back",
        ],
        tags=["CLI", "WRITE"],
        log="np_soc_target_tcp.log",
        body=[
            "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp %s" % value,
            "${out}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp",
            "Log    ${out}",
            "IT COMMON - Cli Inline Number Should Equal    ${out}    value    %s" % value,
        ],
    )


def _nafe_case(item_id):
    """Run the NAFE calibration of both blocks with the NP DS adjust off."""
    return C(
        "Run the NAFE calibration with the NP DS adjustment disabled",
        doc=[
            "Step 1. Read the JXP tilt of the RF board",
            "Step 2. Disable the NP DS calibration adjustment",
            "Step 3. Run the NAFE calibration of both blocks",
            "Step 4. Enable the NP DS calibration adjustment again",
        ],
        tags=["CLI", "WRITE"],
        log="nafe_calibration.log",
        body=[
            "${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt",
            "TRY",
            "    ${ignore_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_np_ds_calib_adj 1",
            "    ${ignore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj",
            "    Should Contain    ${ignore}    get_ignore_np_ds_calib_adj = 1",
            "    ${calib}=    IT COMMON - Run Dut Command And Return    sc_cli calib_nafe ALLNAFE    timeout=300",
            "    Log    ${calib}",
            "    Should Contain    ${calib}    calib_nafe success",
            "    Should Not Contain    ${calib}    failed",
            "FINALLY",
            "    ${ignore_back}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_np_ds_calib_adj 0",
            "    ${ignore_after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj",
            "    Should Contain    ${ignore_after}    get_ignore_np_ds_calib_adj = 0",
            "END",
        ],
    )


def _manual_calibration_case(item_id, log="calibration_manual.log", title=None):
    """Run one manual calibration pass: DS1, DS2, the target TCP, DS3 and US1.

    The target TCP of the second half of the pass is 0.2 dB below the power
    that the AFE measures, and never below 23.5 dBmV.
    """
    name = title or "Run the manual calibration pass"
    return C(
        name,
        doc=[
            "Step 1. Enter the calibration view",
            "Step 2. Run the DS1 and the DS2 stages in manual mode",
            "Step 3. Read the input power of the AFE",
            "Step 4. Set the NP target TCP to the AFE input TCP minus 0.2 dB,",
            "        at least 23.5 dBmV",
            "Step 5. Run the DS3 and the US1 stages in manual mode",
            "Step 6. Show the calibration status and leave the view",
        ],
        tags=["CLI", "WRITE"],
        log=log,
        body=[
            "${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration",
            "${ds1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds1    timeout=900",
            "Should Contain    ${ds1}    Result: SUCCESS",
            "${ds2}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds2    timeout=900",
            "Should Contain    ${ds2}    Result: SUCCESS",
            # The output of the port status is 32 kB long (1024 pre equalizer
            # coefficients), so it is filtered the way the template does it.
            "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_port_status 0 | grep tcp",
            "Log    ${status}",
            "${input_tcp}=    IT COMMON - Get Cli Field    ${status}    rx_adc_input_power_dbmv_tcp",
            "${target}=    Evaluate    max(float($input_tcp) - 0.2, 23.5)    modules=builtins",
            "${tcp_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp ${target}",
            "${tcp}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp",
            "Log    ${tcp}",
            "IT COMMON - Cli Inline Number Should Equal    ${tcp}    value    ${target}",
            "${ds3}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds3    timeout=900",
            "Should Contain    ${ds3}    Result: SUCCESS",
            "${us1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual us1    timeout=900",
            "Should Contain    ${us1}    Result: SUCCESS",
            "${cal_status}=    IT COMMON - Run Fdx View Command And Return    calibration    show calibration-status",
            "${exit}=    IT COMMON - Fdx Exit View    calibration",
            "Log    ${cal_status}",
            "Should Contain    ${cal_status}    STAGE_DS1, Status: ALIGNED",
            "Should Contain    ${cal_status}    STAGE_DS2, Status: ALIGNED",
            "Should Contain    ${cal_status}    STAGE_DS3, Status: ALIGNED",
            "Should Contain    ${cal_status}    STAGE_US1, Status: ALIGNED",
        ],
    )


def _cm_operational_case(item_id):
    """Ask the cable modem for its DOCSIS operational status over SNMP.

    The template reads the status of the cable modem over SNMP and on the
    console of the cable modem. The SNMP part runs on the DUT, the console
    part is a manual step of the bench procedure.
    """
    return C(
        "Check that the cable modem is operational",
        doc=[
            "Step 1. Ask the cable modem for its DOCSIS operational status",
            "        over SNMP, from the DUT",
            "Step 2. The answer has to be INTEGER: 12, that is operational",
            "Step 3. The console of the cable modem is a manual step of the",
            "        bench procedure: 'CM> show status' has to report",
            "        'Docsis Registration Status: Operational'",
        ],
        tags=["SNMP"],
        log="cm_snmp.log",
        body=[
            "${out}=    IT COMMON - Run Dut Command And Return    snmpget -v2c -c public ${CM_SNMP_ADDRESS} 1.3.6.1.2.1.10.127.1.2.2.1.1.2",
            "Log    ${out}",
            "Should Contain    ${out}    INTEGER: 12",
        ],
    )


def _configuration_state_case(item_id, state):
    """Set the configuration state and read it back over gNMI."""
    return C(
        "Set the configuration state to %s" % state,
        doc=[
            "Step 1. Set the configuration state",
            "Step 2. GET configuration-status over gNMI",
            "Step 3. Check that the spectrum state is %s" % state,
            "Step 4. GET configuration-status/spectrum-state over gNMI",
        ],
        tags=["CLI", "GNMI", "WRITE"],
        log="configuration_state.log",
        vars=[("state", state)],
        body=[
            "${set}=    IT COMMON - Run Fdx Command And Return    configuration-state ${state}",
            "Log    ${set}",
            "Should Contain    ${set}    ${state}",
            "${response}=    IT COMMON - Gnmi Get And Return    configuration-status",
            "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    configuration-status",
            "${spectrum_state}=    IT COMMON - Get Dict Field    ${value}    spectrum-state",
            "Should Be Equal    ${spectrum_state}    ${state}",
            "${leaf_response}=    IT COMMON - Gnmi Get And Return    configuration-status/spectrum-state",
            "${leaf}=    IT COMMON - Gnmi Get Leaf Value    ${leaf_response}    configuration-status/spectrum-state",
            "Should Be Equal    ${leaf}    ${state}",
        ],
    )


def _reboot_case(item_id):
    """Reboot the DUT and wait until it answers again.

    The reset command of the clish takes the SSH session down with it, so the
    answer of the command may be lost on the way out. The command is therefore
    sent without judging its answer.

    The wait alone does not prove that the DUT went down: a reset that the
    clish rejects (e.g. one that is typed into a view that is still open)
    leaves the DUT up and reachable, and the case would pass without a
    reboot. The age of the running system is read before and after, and it
    has to be smaller afterwards.
    """
    return C(
        "Reboot the DUT and wait for it to come back",
        doc=[
            "Step 1. Read how long the DUT has been up",
            "Step 2. Reboot the DUT with the reset command of the clish",
            "Step 3. Wait until the DUT answers again",
            "Step 4. Read the age again and check that the DUT really rebooted",
        ],
        tags=["CLI", "WRITE"],
        log="reboot.log",
        body=[
            "${before}=    IT COMMON - Get Dut Uptime Seconds",
            "Run Keyword And Ignore Error    IT COMMON - Run Fdx Command And Return    reset",
            "IT COMMON - Wait For Dut To Come Back    timeout=900    interval=10",
            "${after}=    IT COMMON - Get Dut Uptime Seconds",
            "Should Be True    ${after} < ${before}"
            "    msg=the DUT did not reboot, the age of the system went from"
            " ${before}s to ${after}s",
        ],
    )


def _spectrum_state_after_reboot_case(item_id, state):
    """Read the spectrum state over gNMI after the reboot."""
    return C(
        "Check the spectrum state after the reboot",
        doc=[
            "Step 1. GET configuration-status over gNMI",
            "Step 2. The spectrum state has to be %s" % state,
            "Step 3. GET configuration-status/spectrum-state over gNMI",
        ],
        tags=["GNMI"],
        log="spectrum_state_after_reboot.log",
        vars=[("state", state)],
        body=[
            "${response}=    IT COMMON - Gnmi Get And Return    configuration-status",
            "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    configuration-status",
            "${spectrum_state}=    IT COMMON - Get Dict Field    ${value}    spectrum-state",
            "Should Be Equal    ${spectrum_state}    ${state}",
            "${leaf_response}=    IT COMMON - Gnmi Get And Return    configuration-status/spectrum-state",
            "${leaf}=    IT COMMON - Gnmi Get Leaf Value    ${leaf_response}    configuration-status/spectrum-state",
            "Should Be Equal    ${leaf}    ${state}",
        ],
    )


def _rlsp_case(item_id):
    """Set the legacy RLSP of both ports to 8 dBmV and read it back."""
    return C(
        "Set the legacy RLSP of both ports",
        doc=[
            "Step 1. Read the legacy RLSP of both ports",
            "Step 2. Set both to 8 dBmV",
            "Step 3. Read them back",
        ],
        tags=["CLI", "WRITE"],
        log="legacy_rlsp.log",
        body=[
            "${before_north}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp north",
            "${before_south}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp south",
            "${set_north}=    IT COMMON - Run Dut Command And Return    sc_cli set_legacy_rlsp north 8",
            "${set_south}=    IT COMMON - Run Dut Command And Return    sc_cli set_legacy_rlsp south 8",
            "${north}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp north",
            "${south}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp south",
            "Log    ${north}",
            "Should Contain    ${north}    North Port rlsp: 8.000000 dBmv",
            "Should Contain    ${south}    South Port rlsp: 8.000000 dBmv",
        ],
    )


def _calibration_flags_case(item_id):
    """Put the RF board into the state the calibration needs."""
    return C(
        "Allow the calibration to adjust the attenuations",
        doc=[
            "Step 1. Read the four calibration control flags",
            "Step 2. Allow the NP DS calibration adjustment and the legacy vATT adjustment",
            "Step 3. Read the flags back",
            "Step 4. Set the station mode to with_cable_sim",
        ],
        tags=["CLI", "WRITE"],
        log="calibration_flags.log",
        body=[
            "${ignore_before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj",
            "${auto_before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_auto_adj_legacy_vatt",
            "${station_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode",
            "${ignore_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_np_ds_calib_adj 0",
            "${auto_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_auto_adj_legacy_vatt 1",
            "${ignore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj",
            "${auto}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_auto_adj_legacy_vatt",
            "Should Contain    ${ignore}    get_ignore_np_ds_calib_adj = 0",
            "Should Contain    ${auto}    get_auto_adj_legacy_vatt = 1",
            "${station_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_station_mode with_cable_sim",
            "${station}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode",
            "Should Contain    ${station}    with_cable_sim",
        ],
    )


def _clear_calib_flag_case(item_id):
    """Clear the calibration required flag so that the ASC is not gated."""
    return C(
        "Clear the calibration required flag",
        doc=[
            "Step 1. Read the calibration required flag",
            "Step 2. Clear it",
            "Step 3. Read it back",
        ],
        tags=["CLI", "WRITE"],
        log="calib_req_flag.log",
        body=[
            "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag",
            "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_calib_req_config_flag false",
            "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag",
            "Log    ${after}",
            "Should Contain    ${after}    flag: false",
        ],
    )


S(
    "ALN-001",
    sheet="ALIGNMENT",
    area=CLI_CAL,
    comment="Run the NAFE calibration of the two NAFE blocks and of both of them",
    doc="Run sc_cli calib_nafe for NAFE_BO1, NAFE_BO2 and ALLNAFE and check "
        "that each calibration completes without error (User Guide 3.5, 7.2.2).",
    cases=[
        C(
            "Calibrate the NAFE block 1",
            doc=[
                "Step 1. Run sc_cli calib_nafe NAFE_BO1",
                "Step 2. Check that the calibration succeeded",
            ],
            tags=["CLI", "WRITE"],
            log="nafe_bo1.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    sc_cli calib_nafe NAFE_BO1    timeout=120",
                "Log    ${out}",
                "Should Contain    ${out}    calib_nafe success"
                "    msg=the calibration of the NAFE block 1 did not end with the success marker",
                "Should Not Contain    ${out}    failed"
                "    msg=the calibration of the NAFE block 1 reported a failure",
            ],
        ),
        C(
            "Calibrate the NAFE block 2",
            doc=[
                "Step 1. Run sc_cli calib_nafe NAFE_BO2",
                "Step 2. Check that the calibration succeeded",
            ],
            tags=["CLI", "WRITE"],
            log="nafe_bo2.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    sc_cli calib_nafe NAFE_BO2    timeout=120",
                "Log    ${out}",
                "Should Contain    ${out}    calib_nafe success"
                "    msg=the calibration of the NAFE block 2 did not end with the success marker",
                "Should Not Contain    ${out}    failed"
                "    msg=the calibration of the NAFE block 2 reported a failure",
            ],
        ),
        C(
            "Calibrate both NAFE blocks",
            doc=[
                "Step 1. Run sc_cli calib_nafe ALLNAFE",
                "Step 2. Check that the calibration succeeded",
            ],
            tags=["CLI", "WRITE"],
            log="allnafe.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    sc_cli calib_nafe ALLNAFE    timeout=120",
                "Log    ${out}",
                "Should Contain    ${out}    calib_nafe success"
                "    msg=the calibration of both NAFE blocks did not end with the success marker",
                "Should Not Contain    ${out}    failed"
                "    msg=the calibration of both NAFE blocks reported a failure",
            ],
        ),
    ],
)

S(
    "ALN-002",
    bench=True,
    sheet="ALIGNMENT",
    area=FDX_ALIGN,
    comment="Non FDX alignment, Down / Down / Down",
    doc="Set the ds-profile, the us-profile and the spectrum allocation to "
        "Non-FDX (Down, Down, Down), run the PAB FreeRun and the Non-FDX "
        "alignment flow DS1 -> DS2 -> DS3 -> US (User Guide 5.1, 7.1, 7.2.1). "
        "The DUT is rebooted between the configuration and the PAB, which is a "
        "step of the bench procedure.",
    cases=[
        _ds_profile_case("ALN-002", "north", "profile-3", "120000000", "31.8", "1002000000", "45.0"),
        _ds_profile_case("ALN-002", "south", "profile-3", "120000000", "31.8", "1002000000", "45.0"),
        _rlsp_case("ALN-002"),
        _spectrum_case("ALN-002", "108000000", "684000000", "ds"),
        _configuration_state_case("ALN-002", "MID_SPLIT"),
        _reboot_case("ALN-002"),
        _spectrum_state_after_reboot_case("ALN-002", "MID_SPLIT"),
        _pab_case("ALN-002", "2", "36.00", "-21.78"),
        _calibration_flags_case("ALN-002"),
        _alignment_stages_case("ALN-002", ["ds1", "ds2", "ds3", "us"]),
        C(
            "Adjust the JXP tilt and the US DAC",
            doc=[
                "Step 1. Read the JXP tilt of the RF board",
                "Step 2. Disable the US DAC so that it does not affect the FDX US path",
                "Step 3. Set the US FDX out attenuation",
            ],
            tags=["CLI", "WRITE"],
            log="jxp_dac.log",
            body=[
                "${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt",
                "Log    ${jxp}",
                "Should Contain    ${jxp}    get_legacy_up_jxp_tilt =",
                "${dac}=    IT COMMON - Run Dut Hal Command And Return    /leap/np_dac_power_mode_set 0 0",
                "Log    ${dac}",
                "Should Contain    ${dac}    Successfully set NP-DAC power mode",
                "${atten}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_attenuation 5 31.5",
                "Log    ${atten}",
            ],
        ),
        _clear_calib_flag_case("ALN-002"),
    ],
)

S(
    "ALN-003",
    bench=True,
    sheet="ALIGNMENT",
    area=FDX_ALIGN,
    comment="Non FDX alignment, Legacy Mid-Split",
    doc="Set the ds-profile, the us-profile and the spectrum allocation to "
        "Non-FDX (Legacy Mid-Split), run the PAB FreeRun and the Non-FDX "
        "alignment flow DS1 -> DS2 -> DS3 -> US (User Guide 5.2, 7.1, 7.2.1). "
        "The DUT is rebooted between the configuration and the PAB, which is a "
        "step of the bench procedure.",
    cases=[
        _ds_profile_case("ALN-003", "north", "profile-3", "120000000", "31.8", "1002000000", "45.0"),
        _ds_profile_case("ALN-003", "south", "profile-3", "120000000", "31.8", "1002000000", "45.0"),
        _rlsp_case("ALN-003"),
        C(
            "Apply the Legacy Mid-Split spectrum allocation",
            doc=[
                "Step 1. Enter the spectrum view",
                "Step 2. Set the downstream and the legacy upstream range",
                "Step 3. Remove the three subbands, the current version has a",
                "        minimum subband number limitation",
                "Step 4. Remove the frequency exclusions, the preset below has",
                "        none and the commit refuses the allocation as long as",
                "        one of them is there",
                "Step 5. Apply the Legacy_MidSplit_DS_1.2GHz preset and commit it",
                "Step 6. Check the allocation over sc_cli",
            ],
            tags=["CLI", "WRITE"],
            log="spectrum.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum",
                "${ds_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-start-freq 108000000",
                "${ds_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-end-freq 1218000000",
                "${us_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-start-freq 5000000",
                "${us_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-end-freq 85000000",
                "${ext_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-start-freq 0",
                "${ext_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-end-freq 0",
                "${rm0}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband remove 0",
                "${rm1}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband remove 1",
                "${rm2}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband remove 2",
                # The frequency exclusions have to go as well: the allocation
                # of the preset has none, and the AMP refuses to apply an
                # allocation without a subband that still carries one.
                "${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
                "${exclusions}=    IT COMMON - Get Count After Label    ${before}    Total frequency exclusions",
                "Log    ${before}",
                "FOR    ${index}    IN RANGE    ${exclusions}",
                "    ${rm_excl}=    IT COMMON - Run Fdx View Command And Return    spectrum    remove freq-exclusion ${index}",
                "END",
                "${preset}=    IT COMMON - Run Fdx View Command And Return    spectrum    debug sc_cli set_spectrum_allocation Legacy_MidSplit_DS_1.2GHz",
                # The commit applies the new allocation to the hardware, and
                # the clish only answers when that is done.
                "${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit    timeout=120",
                "Should Contain    ${commit}    applied local configuration",
                "${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
                "${exit}=    IT COMMON - Fdx Exit View    spectrum",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_spectrum_allocation",
                "Log    ${cli}",
                "Should Contain    ${cli}    description: Legacy_MidSplit_DS_1.2GHz",
                "Should Contain    ${cli}    dsBeginHz: 108000000",
                "Should Contain    ${cli}    dsEndHz: 1218000000",
                "Should Contain    ${cli}    usExtendedBeginHz: 0",
            ],
        ),
        _configuration_state_case("ALN-003", "MID_SPLIT"),
        _reboot_case("ALN-003"),
        _spectrum_state_after_reboot_case("ALN-003", "MID_SPLIT"),
        _pab_case("ALN-003", "2", "36.00", "-21.78"),
        _calibration_flags_case("ALN-003"),
        _alignment_stages_case("ALN-003", ["ds1", "ds2", "ds3", "us"]),
        C(
            "Adjust the JXP tilt and the US DAC",
            doc=[
                "Step 1. Read the JXP tilt of the RF board",
                "Step 2. Disable the US DAC so that it does not affect the FDX US path",
                "Step 3. Set the US FDX out attenuation",
            ],
            tags=["CLI", "WRITE"],
            log="jxp_dac.log",
            body=[
                "${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt",
                "Log    ${jxp}",
                "Should Contain    ${jxp}    get_legacy_up_jxp_tilt =",
                "${dac}=    IT COMMON - Run Dut Hal Command And Return    /leap/np_dac_power_mode_set 0 0",
                "Log    ${dac}",
                "Should Contain    ${dac}    Successfully set NP-DAC power mode",
                "${atten}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_attenuation 5 31.5",
                "Log    ${atten}",
            ],
        ),
        _clear_calib_flag_case("ALN-003"),
    ],
)

S(
    "ALN-004",
    bench=True,
    sheet="ALIGNMENT",
    area=FDX_ALIGN,
    comment="Full FDX alignment, AUTO calibration and a second manual pass",
    doc="Configure the Full FDX lineup, run the PAB FreeRun until the eCM is "
        "operational, then run the full FDX calibration: AUTO calibration, "
        "NAFE backoff, reboot and a second manual pass (IT-025, User Guide "
        "5.3, 7.2.2). The DUT is rebooted twice, which is a step of the bench "
        "procedure.",
    cases=[
        _ds_profile_case("ALN-004", "north", "profile-4", "108000000", "32.0", "1218000000", "53.0"),
        _ds_profile_case("ALN-004", "south", "profile-4", "108000000", "32.0", "1218000000", "53.0"),
        _us_profile_rlsp_case("ALN-004"),
        _spectrum_case("ALN-004", "108000000", "684000000", "bidi"),
        _configuration_state_case("ALN-004", "FDX_FINE"),
        _np_soc_target_tcp_case("ALN-004", "29"),
        # The template reboots the DUT here, after the spectrum allocation
        # and the configuration state are set.
        _reboot_case("ALN-004"),
        _spectrum_state_after_reboot_case("ALN-004", "FDX_FINE"),
        _pab_case("ALN-004", "3", "29", "-27.78"),
        _cm_operational_case("ALN-004"),
        C(
            "Run the AUTO calibration",
            doc=[
                "Step 1. Enter the calibration view",
                "Step 2. Start the calibration in auto mode",
                "Step 3. The four stages have to run and end with a success",
                "Step 4. Show the calibration status",
                "Step 5. Leave the view",
            ],
            tags=["CLI", "WRITE"],
            log="calibration_auto.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration",
                "${start}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration    timeout=1800",
                "Log    ${start}",
                "Should Contain    ${start}    Progress: STAGE_DS1",
                "Should Contain    ${start}    Progress: STAGE_DS2",
                "Should Contain    ${start}    Progress: STAGE_DS3",
                "Should Contain    ${start}    Progress: STAGE_US1",
                "Should Contain    ${start}    Result: SUCCESS",
                "${status}=    IT COMMON - Run Fdx View Command And Return    calibration    show calibration-status",
                "${exit}=    IT COMMON - Fdx Exit View    calibration",
                "Log    ${status}",
                "Should Contain    ${status}    STAGE_DS1, Status: ALIGNED",
                "Should Contain    ${status}    STAGE_DS2, Status: ALIGNED",
                "Should Contain    ${status}    STAGE_DS3, Status: ALIGNED",
                "Should Contain    ${status}    STAGE_US1, Status: ALIGNED",
            ],
        ),
        _nafe_case("ALN-004"),
        C(
            "Apply the NAFE calibration output and restore the target TCP",
            doc=[
                "Step 1. Set the interference ratio based to 0.0078125",
                "Step 2. Set the NP SoC target TCP to 36 dBmV",
                "Step 3. Read both back",
            ],
            tags=["CLI", "WRITE"],
            log="nafe_output.log",
            body=[
                "${ratio_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_interference_ratio_based 0.0078125",
                "${ratio}=    IT COMMON - Run Dut Command And Return    sc_cli get_interference_ratio_based",
                "Log    ${ratio}",
                "IT COMMON - Cli Inline Number Should Equal    ${ratio}    value    0.0078125",
                "${tcp_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp 36",
                "${tcp}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp",
                "Log    ${tcp}",
                "IT COMMON - Cli Inline Number Should Equal    ${tcp}    value    36",
            ],
        ),
        # The template reboots the DUT here, so that the NAFE result is
        # applied and the second pass starts from a clean system.
        _reboot_case("ALN-004"),
        _manual_calibration_case(
            "ALN-004", log="calibration_manual.log",
            title="Run the second calibration pass"),
        _clear_calib_flag_case("ALN-004"),
    ],
)


def _partial_fdx_suite(item_id, start_freq, start_power, subband, comment, doc):
    """Build the suite of a Partial FDX lineup.

    ALN-005 and ALN-006 are the same flow with a different lineup: the
    ds-profile of the two ports differs, and the subbands of the spectrum
    allocation are either "us" (without dummy DS energy) or "bidi" (with it).
    The frequency exclusion is the same in both.

    The row of the template is cut off in the middle of the second pass, so
    the second pass is rebuilt after the first one: the stages are the same,
    and so is the rule for the target TCP.
    """
    return S(
        item_id,
        bench=True,
        sheet="ALIGNMENT",
        area=FDX_ALIGN,
        comment=comment,
        doc=doc,
        cases=[
            _ds_profile_case(item_id, "north", "profile-3", start_freq, start_power, "1098000000", "46.4"),
            _ds_profile_case(item_id, "south", "profile-3", start_freq, start_power, "1098000000", "46.4"),
            _us_profile_rlsp_case(item_id),
            _spectrum_case(
                item_id, "108000000", "396000000", subband,
                exclusion="383000000 396000000 PASS_OTHER EXCLUDED"),
            _np_soc_target_tcp_case(item_id, "29"),
            _configuration_state_case(item_id, "FDX_FINE"),
            # The template reboots the DUT after the spectrum allocation and
            # the configuration state are set.
            _reboot_case(item_id),
            _spectrum_state_after_reboot_case(item_id, "FDX_FINE"),
            _pab_case(item_id, "2", "36.00", "-21.78"),
            _calibration_flags_case(item_id),
            _manual_calibration_case(
                item_id, log="calibration_manual_1.log",
                title="Run the first manual calibration pass"),
            C(
                "Adjust the JXP tilt",
                doc=[
                    "Step 1. Read the JXP tilt of the RF board",
                    "Step 2. The US legacy calibration assumes a JXP value of 0 dB",
                ],
                tags=["CLI", "WRITE"],
                log="jxp_tilt.log",
                body=[
                    "${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt",
                    "Log    ${jxp}",
                    "Should Contain    ${jxp}    get_legacy_up_jxp_tilt =",
                ],
            ),
            _nafe_case(item_id),
            C(
                "Set the interference ratio and the target TCP",
                doc=[
                    "Step 1. Set the interference ratio based to 3 dB",
                    "Step 2. Set the NP SoC target TCP back to 36 dBmV",
                    "Step 3. Read both back",
                ],
                tags=["CLI", "WRITE"],
                log="nafe_output.log",
                body=[
                    "${ratio_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_interference_ratio_based 3",
                    "${ratio}=    IT COMMON - Run Dut Command And Return    sc_cli get_interference_ratio_based",
                    "Log    ${ratio}",
                    "IT COMMON - Cli Inline Number Should Equal    ${ratio}    value    3",
                    "${tcp_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp 36",
                    "${tcp}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp",
                    "Log    ${tcp}",
                    "IT COMMON - Cli Inline Number Should Equal    ${tcp}    value    36",
                ],
            ),
            # The template reboots the DUT here, so that the NAFE result is
            # applied and the second pass starts from a clean system.
            _reboot_case(item_id),
            _manual_calibration_case(
                item_id, log="calibration_manual_2.log",
                title="Run the second manual calibration pass"),
            _clear_calib_flag_case(item_id),
        ],
    )


_partial_fdx_suite(
    "ALN-005",
    "384000000", "36.0", "us",
    comment="Partial FDX alignment without dummy DS energy",
    doc="Set the ds-profile, the us-profile and the spectrum allocation to "
        "Partial FDX without Dummy DS Energy (the three subbands are "
        "upstream only), run the PAB FreeRun, the FDX calibration flow, the "
        "NAFE calibration and the second pass (User Guide 5.5, 7.1, 7.2.2). "
        "The AUTO calibration is not used here, the stages are run manually "
        "the way the workaround of the User Guide says. The DUT is rebooted "
        "twice, which is a step of the bench procedure.",
)

_partial_fdx_suite(
    "ALN-006",
    "108000000", "31.8", "bidi",
    comment="Partial FDX alignment with dummy DS energy",
    doc="Set the ds-profile, the us-profile and the spectrum allocation to "
        "Partial FDX with Dummy DS Energy (the three subbands are bidi and "
        "the frequency exclusion is added), run the PAB FreeRun, the FDX "
        "calibration flow, the NAFE calibration and the second pass (User "
        "Guide 5.4, 7.1, 7.2.2). The AUTO calibration is not used here, the "
        "stages are run manually the way the workaround of the User Guide "
        "says. The DUT is rebooted twice, which is a step of the bench "
        "procedure.",
)

for _spec in SUITES:
        if _spec["id"] in {"ALN-002", "ALN-003", "ALN-004", "ALN-005", "ALN-006"}:
            _spec["vars"].append(("ALN_LINEUP_FAILED", "${FALSE}"))
            for _index, _case in enumerate(_spec["cases"]):
                _guard = [
                    "IF    $ALN_LINEUP_FAILED",
                    "    Skip    A preceding lineup configuration failed; dependent steps must not run.",
                    "END",
                ]
                if _index < 4:
                    _case["body"] = (_guard
                                     + ["Set Suite Variable    ${ALN_LINEUP_FAILED}    ${TRUE}"]
                                     + _case["body"]
                                     + ["Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}"])
                else:
                    _case["body"] = _guard + _case["body"]

_aln007 = S(
    "ALN-007",
    bench=True,
    sheet="ALIGNMENT",
    area=LEGACY_US,
    comment="Legacy US calibration and the factory compensation of the eCM offset",
    doc="Set the eCM offset to the default 15, run calib_us_legacy with a 0 dB "
        "JXP installed, adjust the JXP tilt and update "
        "/mnt/sc_factory/ecm_rfb_offset from the measured RLSP deviation "
        "(User Guide 4, 10.5). Skipped: a manual RLSP measurement is required "
        "after calibration; the suite cannot wait for it.",
    vars=[
        # The offset the file holds before the suite changes it. The suite
        # puts it back at the end, so the unit keeps what it came with.
        ("ALN007_ORIGINAL_OFFSET", "${NONE}"),
        # The offset the procedure starts from: the default 15 that the User
        # Guide asks for (Note 2 of chapter 4).
        ("ALN007_BASE_OFFSET", "${NONE}"),
        ("ALN007_CALIBRATION_LOG", "${NONE}"),
        # The deviation of the RLSP that was measured on the bench with a
        # meter. The case that writes the file fails without it.
        ("ALN007_MANUAL_DEVIATION", "${EMPTY}"),
    ],
    cases=[
        C(
            "Read the eCM TX power limits",
            doc=[
                "Step 1. Read the minimum and the maximum eCM TX power",
                "Step 2. Check that the eCM is operational",
                "",
                "The limits are the window in which the TX power of the eCM",
                "counts as valid. The legacy US calibration only runs its eCM",
                "branch when the TX power of the eCM is inside that window",
                "(User Guide 4, Step 1 and Step 2).",
                "",
                "The upper limit is NOT written here. It is not a constant of",
                "the software but a nonvol value that the factory sets",
                "(/alignment/max_ecm_tx_power_v2, 52.75 dBmV on the unit of",
                "the bench), so the factory value is kept and the window the",
                "calibration really used is read back from the log of the",
                "alignment in the next case.",
            ],
            tags=["CLI"],
            log="ecm_tx_power.log",
            body=[
                "${min}=    IT COMMON - Run Dut Command And Return    sc_cli get_min_ecm_tx_power",
                "${max}=    IT COMMON - Run Dut Command And Return    sc_cli get_max_ecm_tx_power",
                "Log    ${min}",
                "Log    ${max}",
                "Should Contain    ${min}    get_min_ecm_tx_power success",
                "Should Contain    ${max}    get_max_ecm_tx_power success",
                "${min_v}=    IT COMMON - Get Inline Field    ${min}    value",
                "${max_v}=    IT COMMON - Get Inline Field    ${max}    value",
                "${min_n}=    Evaluate    float($min_v)    modules=builtins",
                "${max_n}=    Evaluate    float($max_v)    modules=builtins",
                "Log    The window of the eCM TX power is ${min_n} to ${max_n} dBmV",
                # The eCM walks through a series of states before it is
                # operational: RangeStart -> StartDsAcquisition ->
                # StartUsAcquisition -> RangeStart -> Operational. Measured:
                # 4m43s after the PAB FreeRun was over on one bench unit,
                # 3m29s after the reboot on another one. The window has to be
                # wide enough for that.
                "${ecm}=    IT COMMON - Wait For Dut Command Contains    sc_amphal_cli get_ecm_status    eCM status = Operational    timeout=600    interval=10",
                "Log    ${ecm}",
            ],
        ),
        C(
            "Set the eCM offset to the default 15",
            doc=[
                "Step 1. Read /mnt/sc_factory/ecm_rfb_offset and keep the value,",
                "        the suite puts it back at the end",
                "Step 2. Set the offset to the default 15",
                "Step 3. Read it back",
                "",
                "The User Guide asks the operator to start from the default",
                "offset 15 (Note 2 of chapter 4): the eCM reports its power",
                "about 15 dB too high with the new BCM control table, and the",
                "offset is what the algorithm subtracts from that report. The",
                "value in the file is the offset of the unit, it is written by",
                "the factory or by an earlier run of this procedure, never by",
                "the software itself: the alignment, the AGC and the ASC only",
                "read it.",
                "",
                "The 15 is also the base of the compensation that the last case",
                "writes: the User Guide adds the deviation of the measured",
                "RLSP to it.",
            ],
            tags=["FILE", "WRITE"],
            log="ecm_offset.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_factory/ecm_rfb_offset",
                "Log    ${out}",
                "${original}=    Evaluate    $out.strip()",
                "${original_number}=    Evaluate    float($original)",
                "${valid}=    Evaluate    math.isfinite($original_number)    modules=math",
                "Should Be True    ${valid}    Invalid eCM offset: ${original}",
                "Set Suite Variable    ${ALN007_ORIGINAL_OFFSET}    ${original}",
                "Log    The file held ${original}, it is put back at the end of the suite",
                "${write}=    IT COMMON - Run Dut Root Command And Return    echo 15 > /mnt/sc_factory/ecm_rfb_offset",
                "${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_factory/ecm_rfb_offset",
                "Log    ${out}",
                "${base}=    Evaluate    float($out.strip())",
                "Set Suite Variable    ${ALN007_BASE_OFFSET}    ${base}",
                "${is_default}=    Evaluate    abs($base - 15.0) < 0.001    modules=builtins",
                "IF    \"${is_default}\" != \"True\"",
                "    Fail    The eCM offset was set to 15 but the file holds ${base}",
                "END",
            ],
        ),
        C(
            "Run the legacy US calibration",
            doc=[
                "Step 1. Enter the alignment view",
                "Step 2. Run sc_cli calib_us_legacy",
                "Step 3. Check that the calibration ran the eCM method and",
                "        not the fallback of the old method",
                "Step 4. Read the JXP tilt of the RF board",
                "Step 5. Leave the view",
                "",
                "The calibration needs a JXP with 0 dB of attenuation and the",
                "eCM has to be operational. The CLI waits 20 s for the flag of",
                "the alignment thread, so the answer of the command is the",
                "result of the calibration itself.",
                "",
                "The tilt of the JXP is set to 0 before the calibration, that",
                "is the state the User Guide asks for. The calibration writes",
                "the tilt it computed to the RF board, so without this step a",
                "second run of the case would start with the tilt of the",
                "first run and the algorithm would compensate for a JXP",
                "attenuation that is not there.",
            ],
            tags=["CLI", "WRITE"],
            log="calib_us_legacy.log",
            body=[
                "Set Suite Variable    ${ALN007_CALIBRATION_LOG}    ${NONE}",
                "${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt",
                "Log    The JXP tilt before the calibration is ${before}",
                "${zero}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_legacy_up_jxp_tilt 0",
                "Log    ${zero}",
                "Should Contain    ${zero}    set_legacy_up_jxp_tilt...success",
                "${enter}=    IT COMMON - Fdx Enter View    configure alignment    alignment",
                "${cursor}=    IT COMMON - Read Journal Cursor",
                "${calib}=    IT COMMON - Run Fdx View Command And Return    alignment    debug sc_cli calib_us_legacy    timeout=300",
                "Log    ${calib}",
                "Should Contain    ${calib}    calib_us_legacy success",
                # The result file of the calibration holds the branch that was
                # taken. The eCM method is the one of the procedure, the old
                # method is the fallback for an eCM that is not operational or
                # whose TX power is out of the window of the limits.
                "Should Contain    ${calib}    by eCM Tx Power",
                "Should Not Contain    ${calib}    old method",
                "${journal}=    IT COMMON - Read Legacy Calibration Journal    ${cursor}",
                "${exit}=    IT COMMON - Fdx Exit View    alignment",
                "${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt",
                "Log    ${jxp}",
                "${tilt}=    IT COMMON - Get Inline Field    ${jxp}    get_legacy_up_jxp_tilt",
                "${tilt_n}=    Evaluate    float($tilt)    modules=builtins",
                "${in_range}=    Evaluate    0 <= $tilt_n <= 6    modules=builtins",
                "IF    \"${in_range}\" != \"True\"",
                "    Fail    The legacy upstream JXP tilt is ${tilt_n} dB, the algorithm of the calibration knows 0 to 6 dB",
                "END",
                "Log    The legacy upstream JXP tilt is ${tilt_n} dB",
                "Set Suite Variable    ${ALN007_CALIBRATION_LOG}    ${journal}",
            ],
        ),
        C(
            "Check the US TXPWR of the eCM",
            doc=[
                "Step 1. Read the journal record captured during this suite's legacy calibration",
                "Step 2. Check that the eCM was operational during the calibration",
                "Step 3. The TX power of the eCM has to be inside the window",
                "        of the limits that the calibration used",
                "",
                "The User Guide asks for the TX power of the eCM to be inside",
                "the window of 17.25 to 50 dBmV but it gives no command for it.",
                "The alignment thread writes the TX power of the eCM and the",
                "window it used into its log, so the check reads them there.",
                "The User Guide marks the range with a (Need update).",
                "",
                "The window in the log is the one the calibration really used,",
                "so the check holds whatever the factory wrote into the nonvol",
                "and not a number of the test case.",
            ],
            tags=["LOG"],
            log="ecm_tx_power_window.log",
            body=[
                "${log}=    Get Variable Value    ${ALN007_CALIBRATION_LOG}    default=${NONE}",
                "Should Not Be Equal    ${log}    ${NONE}    msg=No journal record from this suite's successful legacy calibration.",
                "Log    ${log}",
                "${cm}=    IT COMMON - Get Inline Field    ${log}    isCmOperational",
                "Should Be Equal    ${cm}    1    msg=eCM was not operational during legacy calibration: ${cm}",
                "${pwr1}=    IT COMMON - Get Inline Field    ${log}    ecmTxPwrF1",
                "${pwr2}=    IT COMMON - Get Inline Field    ${log}    ecmTxPwrF2",
                "${low}=    IT COMMON - Get Inline Field    ${log}    minEcmTxPower",
                "${high}=    IT COMMON - Get Inline Field    ${log}    maxEcmTxPower",
                "${pwr1_n}=    Evaluate    float($pwr1)    modules=builtins",
                "${pwr2_n}=    Evaluate    float($pwr2)    modules=builtins",
                "${low_n}=    Evaluate    float($low)    modules=builtins",
                "${high_n}=    Evaluate    float($high)    modules=builtins",
                "Log    The eCM was operational (${cm}), its US TX power is ${pwr1_n} and ${pwr2_n} dBmV, the window is ${low_n} to ${high_n} dBmV",
                "${in_window}=    Evaluate    ($low_n < $pwr1_n < $high_n) and ($low_n < $pwr2_n < $high_n)    modules=builtins",
                "IF    \"${in_window}\" != \"True\"",
                "    Fail    The US TX power of the eCM is ${pwr1_n} / ${pwr2_n} dBmV, the window is ${low_n} to ${high_n} dBmV",
                "END",
            ],
        ),
        C(
            "Measure the RLSP and compute the deviation",
            doc=[
                "Step 1. Read the RLSP of the south port and the legacy RLSP",
                "Step 2. The deviation is the target RLSP minus the measured RLSP",
                "",
                "The User Guide measures the RLSP at SP_US_TP with a meter",
                "while the US runs at about 100% of the utilization, that is a",
                "bench action. The DUT holds the same two numbers, the RLSP of",
                "the upstream profile of the south port is the target and the",
                "legacy RLSP is the one that the calibration measured, so the",
                "deviation of the DUT is shown here as the number the meter",
                "has to confirm.",
                "",
                "The deviation that goes into the file is the one that was",
                "measured on the bench, it is given with the variable",
                "ALN007_MANUAL_DEVIATION. The case that writes the file fails",
                "without it.",
            ],
            tags=["CLI"],
            log="rlsp.log",
            body=[
                "${rlsp}=    IT COMMON - Run Dut Command And Return    sc_cli get_rlsp_all south",
                "Log    ${rlsp}",
                "${target}=    IT COMMON - Get Number After Colon    ${rlsp}    South Port rlsp",
                "${measured}=    IT COMMON - Get Number After Colon    ${rlsp}    South Port legacy rlsp",
                "${dev}=    Evaluate    round($target - $measured, 3)    modules=builtins",
                "Log    The target RLSP is ${target} dBmV and the RLSP of the calibration is ${measured} dBmV, the deviation of the DUT is ${dev} dB",
                "${manual}=    Get Variable Value    ${ALN007_MANUAL_DEVIATION}    default=${EMPTY}",
                "IF    \"${manual}\" != \"${EMPTY}\"",
                "    ${given}=    Evaluate    float($manual)    modules=builtins",
                "    Log    The deviation that goes into the file is ${given} dB, it comes from the measurement on the bench",
                "ELSE",
                "    Log    No deviation was measured on the bench, the case that writes the file fails",
                "END",
            ],
        ),
        C(
            "Write the compensated eCM offset",
            doc=[
                "Step 1. The offset is the default 15 plus the deviation that",
                "        was measured on the bench, e.g. 8.0 - 8.5 = -0.5 dB",
                "        gives 14.5",
                "Step 2. Write the offset and read it back",
                "",
                "The deviation comes from the measurement of the RLSP at",
                "SP_US_TP with the US running at about 100% of the utilization,",
                "which is a bench action, so the case fails when it is not",
                "given: --variable ALN007_MANUAL_DEVIATION:<deviation in dB>.",
                "",
                "The file is put back to the value it had before the suite in",
                "the teardown, so that the bench unit keeps the compensation it",
                "came with.",
            ],
            tags=["FILE", "WRITE"],
            log="ecm_offset_write.log",
            body=[
                "${manual}=    Get Variable Value    ${ALN007_MANUAL_DEVIATION}    default=${EMPTY}",
                "IF    \"${manual}\" == \"${EMPTY}\"",
                "    Fail    The eCM offset needs the deviation of the RLSP that was measured on the bench. Measure the RLSP at SP_US_TP with the US running at about 100% of the utilization, take the target RLSP minus the measured RLSP, and run the suite with --variable ALN007_MANUAL_DEVIATION:<the deviation in dB>.",
                "END",
                "${base}=    Get Variable Value    ${ALN007_BASE_OFFSET}    default=${NONE}",
                "${dev}=    Evaluate    float($manual)    modules=builtins",
                "${valid}=    Evaluate    math.isfinite($dev)    modules=math",
                "Should Be True    ${valid}    Invalid RLSP deviation: ${manual}",
                "${new}=    Evaluate    round(float($base) + $dev, 3)    modules=builtins",
                "${valid}=    Evaluate    math.isfinite($new)    modules=math",
                "Should Be True    ${valid}    Invalid eCM offset: ${new}",
                "Log    The eCM offset goes from ${base} to ${new}, the default ${base} plus the deviation ${dev}",
                "${write}=    IT COMMON - Run Dut Root Command And Return    echo ${new} > /mnt/sc_factory/ecm_rfb_offset",
                "${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_factory/ecm_rfb_offset",
                "Log    ${out}",
                "${read}=    Evaluate    float($out.strip())",
                "${same}=    Evaluate    abs($read - $new) < 0.001    modules=builtins",
                "IF    \"${same}\" != \"True\"",
                "    Fail    The eCM offset was written as ${new}, the file holds ${read}",
                "END",
            ],
        ),
    ],
    teardown=[
        "${original}=    Get Variable Value    ${ALN007_ORIGINAL_OFFSET}    default=${NONE}",
        "IF    \"${original}\" != \"${NONE}\"",
        "    Run Keyword And Continue On Failure    IT COMMON - Restore eCM Factory Offset    ${original}",
        "END",
    ],
)

for _case in _aln007["cases"]:
    _case["tags"].extend(["MANUAL_RLSP", "robot:skip"])

S(
    "ALN-008",
    bench=True,
    sheet="ALIGNMENT",
    area=CLISH_CAL,
    comment="The auto, semi-auto and manual modes of the clish calibration",
    doc="Verify the CLISH calibration sub-modes (auto, semi-auto <stage>, "
        "manual <stage>), show calibration-status and the sequential stage "
        "dependency rule (User Guide 10.13).",
    cases=[
        C(
            "Run the calibration in auto mode",
            doc=[
                "Step 1. Enter the calibration view",
                "Step 2. Start the calibration in auto mode",
                "Step 3. Check that the four stages ran, in order, and that the",
                "        calibration finished with SUCCESS",
                "Step 4. Leave the view",
                "",
                "The command prints one progress line per stage and the result",
                "of the calibration at the end. The auto mode runs every stage",
                "of the lineup in order: DS1, DS2, DS3 and US1. Measured on the",
                "bench: about two minutes.",
            ],
            tags=["CLI", "WRITE"],
            log="auto.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration",
                "${start}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration auto    timeout=600",
                "Log    ${start}",
                "Should Contain    ${start}    Progress: STAGE_DS1",
                "Should Contain    ${start}    Progress: STAGE_DS2",
                "Should Contain    ${start}    Progress: STAGE_DS3",
                "Should Contain    ${start}    Progress: STAGE_US1",
                "${order}=    IT COMMON - Progress Line Order    ${start}    DS1    DS2    DS3    US1",
                "Log    The stages ran at ${order}",
                "IT COMMON - Check Calibration Result    ${start}    0",
                "${exit}=    IT COMMON - Fdx Exit View    calibration",
            ],
        ),
        C(
            "Run the calibration in semi-auto mode from the DS1 stage",
            doc=[
                "Step 1. Enter the calibration view",
                "Step 2. Start the calibration in semi-auto mode from ds1",
                "Step 3. Check that it ran through the remaining stages on its",
                "        own and finished with SUCCESS",
                "Step 4. Leave the view",
                "",
                "The semi-auto mode starts at the stage that is given and then",
                "goes on by itself through the remaining stages. Measured on the",
                "bench: about two minutes, the same as the auto mode.",
            ],
            tags=["CLI", "WRITE"],
            log="semi_auto.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration",
                "${start}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration semi-auto ds1    timeout=600",
                "Log    ${start}",
                "Should Contain    ${start}    Progress: STAGE_DS1",
                "Should Contain    ${start}    Progress: STAGE_DS2",
                "Should Contain    ${start}    Progress: STAGE_DS3",
                "Should Contain    ${start}    Progress: STAGE_US1",
                "${order}=    IT COMMON - Progress Line Order    ${start}    DS1    DS2    DS3    US1",
                "Log    The stages ran at ${order}",
                "IT COMMON - Check Calibration Result    ${start}    0",
                "${exit}=    IT COMMON - Fdx Exit View    calibration",
            ],
        ),
        C(
            "Run every stage on its own in manual mode",
            doc=[
                "Step 1. Enter the calibration view",
                "Step 2. Start the calibration in manual mode from ds1, from ds2,",
                "        from ds3 and from us1, one after the other",
                "Step 3. Check that every one of them ran only its own stage and",
                "        finished with SUCCESS",
                "Step 4. Leave the view",
                "",
                "The manual mode runs the stage that is given and nothing else,",
                "that is the difference to the semi-auto mode.",
                "",
                "The stages have to be run one after the other in this order.",
                "Measured on the bench: a stage that is not the first one is",
                "given up on when the stage before it was not run in the manual",
                "mode right before it, the calibration service answers",
                "'Alignment failed for stage: N' (US1=0, DS1=1, DS2=2, DS3=3) and",
                "the alignment log shows that the stage was aborted before it",
                "produced a result. That is the sequential stage dependency rule",
                "of the User Guide (10.13.2 and 10.13.3).",
            ],
            tags=["CLI", "WRITE"],
            log="manual.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration",
                "${ds1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds1    timeout=600",
                "Log    ${ds1}",
                "Should Contain    ${ds1}    Progress: STAGE_DS1",
                "Should Not Contain    ${ds1}    Progress: STAGE_DS2",
                "Should Not Contain    ${ds1}    Progress: STAGE_DS3",
                "Should Not Contain    ${ds1}    Progress: STAGE_US1",
                "IT COMMON - Check Calibration Result    ${ds1}    1",
                "${ds2}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds2    timeout=600",
                "Log    ${ds2}",
                "Should Contain    ${ds2}    Progress: STAGE_DS2",
                "Should Not Contain    ${ds2}    Progress: STAGE_DS1",
                "Should Not Contain    ${ds2}    Progress: STAGE_DS3",
                "Should Not Contain    ${ds2}    Progress: STAGE_US1",
                "IT COMMON - Check Calibration Result    ${ds2}    2",
                "${ds3}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds3    timeout=600",
                "Log    ${ds3}",
                "Should Contain    ${ds3}    Progress: STAGE_DS3",
                "Should Not Contain    ${ds3}    Progress: STAGE_DS1",
                "Should Not Contain    ${ds3}    Progress: STAGE_DS2",
                "Should Not Contain    ${ds3}    Progress: STAGE_US1",
                "IT COMMON - Check Calibration Result    ${ds3}    3",
                "${us1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual us1    timeout=600",
                "Log    ${us1}",
                "Should Contain    ${us1}    Progress: STAGE_US1",
                "Should Not Contain    ${us1}    Progress: STAGE_DS1",
                "Should Not Contain    ${us1}    Progress: STAGE_DS2",
                "Should Not Contain    ${us1}    Progress: STAGE_DS3",
                "IT COMMON - Check Calibration Result    ${us1}    0",
                "${exit}=    IT COMMON - Fdx Exit View    calibration",
            ],
        ),
        C(
            "Check the calibration status",
            doc=[
                "Step 1. Enter the calibration view",
                "Step 2. Show the calibration status",
                "Step 3. Check that the four stages are ALIGNED and that no",
                "        calibration is running",
                "Step 4. Leave the view",
                "",
                "The status is the gRPC GetCalibrationStatus of the calibration",
                "service: one line per stage with the state of the stage, and",
                "the flag that says whether a calibration is running.",
            ],
            tags=["CLI"],
            log="status.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration",
                "${status}=    IT COMMON - Run Fdx View Command And Return    calibration    show calibration-status",
                "${exit}=    IT COMMON - Fdx Exit View    calibration",
                "Log    ${status}",
                "Should Contain    ${status}    Stage: STAGE_DS1, Status: ALIGNED",
                "Should Contain    ${status}    Stage: STAGE_DS2, Status: ALIGNED",
                "Should Contain    ${status}    Stage: STAGE_DS3, Status: ALIGNED",
                "Should Contain    ${status}    Stage: STAGE_US1, Status: ALIGNED",
                "${running}=    IT COMMON - Get Text After Label    ${status}    Calibrating",
                "Should Be Equal    ${running}    false",
            ],
        ),
    ],
)


def _alignment_gnmi_case(alignment_type, prerequisites):
    """Subscribe before triggering one alignment stage."""
    path = "amp-alignment[alignment-type=%s]" % alignment_type
    return C(
        "Trigger %s and subscribe to its alignment status" % alignment_type,
        doc=[
            "Step 1. Wait until no alignment stage is in progress and check prerequisites",
            "Step 2. Start the ON_CHANGE subscription and wait for synchronization",
            "Step 3. Trigger the stage with gNMI SET",
            "Step 4. Verify IN_PROGRESS followed by ALIGNED; FAILURE fails the test",
        ],
        tags=["GNMI", "WRITE"],
        log="alignment_%s.log" % alignment_type.lower(),
        vars=[
            ("path", path),
            ("status_path", "%s/alignment-status" % path),
            ("prerequisites", prerequisites),
        ],
        body=[
            "${idle}=    IT COMMON - Wait For No Gnmi Instance With    amp-alignment[alignment-type=*]    alignment-status    ALIGN_STATUS_IN_PROGRESS    timeout=300",
            "FOR    ${prior}    IN    @{prerequisites}",
            "    ${prior_path}=    Catenate    SEPARATOR=    amp-alignment[alignment-type=${prior}]/alignment-status",
            "    ${prior_response}=    IT COMMON - Gnmi Get And Return    ${prior_path}",
            "    ${prior_status}=    IT COMMON - Gnmi Get Leaf Value    ${prior_response}    ${prior_path}",
            "    Should Be Equal    ${prior_status}    ALIGN_STATUS_ALIGNED    msg=Prerequisite ${prior} is ${prior_status}, not ALIGNED",
            "END",
            "GNMI_IT.Start Subscription    ${status_path}    log_name=${sc_log}",
            "${update}=    Catenate    SEPARATOR=    /    ${path}    /alignment-type:::string:::${alignment_type}",
            "${result}=    GNMI_IT.Set And Return    updates=${update}    resp_timeout=30    log_name=${sc_log}",
            "Should Be Equal    ${result}[results][0][operation]    UPDATE",
            "Should Be Equal    ${result}[results][0][path]    ${path}/alignment-type",
            "${started}=    GNMI_IT.Next Subscription Response    timeout=120",
            "${started_status}=    IT COMMON - Gnmi Get Leaf Value    ${started}    ${status_path}",
            "Should Be Equal    ${started_status}    ALIGN_STATUS_IN_PROGRESS",
            "${deadline}=    Evaluate    time.monotonic() + 300    modules=time",
            "WHILE    True",
            "    ${remaining}=    Evaluate    $deadline - time.monotonic()    modules=time",
            "    IF    $remaining <= 0    Fail    Alignment did not finish within 300 seconds",
            "    ${finished}=    GNMI_IT.Next Subscription Response    timeout=${remaining}",
            "    ${finished_status}=    IT COMMON - Gnmi Get Leaf Value    ${finished}    ${status_path}",
            "    IF    $finished_status == 'ALIGN_STATUS_ALIGNED'    BREAK",
            "    Should Be Equal    ${finished_status}    ALIGN_STATUS_IN_PROGRESS",
            "END",
            "GNMI_IT.Stop Subscription",
        ],
    )


for _item, _type, _prerequisites in [
    ("ALN-009", "ALIGN_DOWNSTREAM_STAGE_1", []),
    ("ALN-010", "ALIGN_DOWNSTREAM_STAGE_2", ALIGNMENT_TYPES[:1]),
    ("ALN-011", "ALIGN_DOWNSTREAM_STAGE_3", ALIGNMENT_TYPES[:2]),
    ("ALN-012", "ALIGN_UPSTREAM", ALIGNMENT_TYPES[:3]),
]:
    S(
        _item,
        sheet="ALIGNMENT",
        area=GNMI_ALIGN,
        comment="Trigger the %s alignment over gNMI" % _type,
        doc="Trigger the alignment stage %s through a gNMI SET and verify the "
            "ON_CHANGE status sequence (User Guide 9.10). Triggering a stage "
            "may invalidate later stages." % _type,
        vars=[("alignment_type", _type)],
        cases=[_alignment_gnmi_case(_type, _prerequisites)],
    )

S(
    "ALN-013",
    sheet="ALIGNMENT",
    area=GNMI_ALIGN,
    comment="Read the whole amp-alignment tree over gNMI",
    doc="Retrieve the amp-alignment root container, every alignment stage "
        "container, the alignment status and the alignment status update time "
        "through gNMI GET (User Guide 9.10.1).",
    vars=[("alignment_types", ALIGNMENT_TYPES)],
    cases=[
        C(
            "GET the amp-alignment root container",
            doc=[
                "Step 1. GET amp-alignment[alignment-type=*]",
                "Step 2. Check that the answer holds the five alignment types",
            ],
            tags=["GNMI"],
            log="1_root.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    amp-alignment[alignment-type=*]",
                "${values}=    IT COMMON - Gnmi Get All Values    ${response}",
                "Log    ${values}",
                # Every instance of the wildcard answer holds the type of its
                # stage in the leaf "alignment-type", the values of the answer
                # are all held under the key "amp-alignment".
                "${types}=    Evaluate    [v.get('alignment-type') for v in $values]    modules=builtins",
                "Log    ${types}",
                "Lists Should Be Equal    ${types}    ${alignment_types}    ignore_order=${True}",
            ],
        ),
        C(
            "GET the container, the status and the update time of every stage",
            doc=[
                "Step 1. GET the stage container, the alignment status and the",
                "        alignment status update time of every alignment type",
                "Step 2. Check that the status is one of the four known states",
                "Step 3. Check that the update time is a timestamp, it is empty",
            ],
            tags=["GNMI"],
            log="2_stages.log",
            body=[
                "FOR    ${type}    IN    @{alignment_types}",
                "    ${container_path}=    Catenate    SEPARATOR=    amp-alignment[alignment-type=${type}]",
                "    ${status_path}=    Catenate    SEPARATOR=    ${container_path}/alignment-status",
                "    ${time_path}=    Catenate    SEPARATOR=    ${container_path}/alignment-status-update-time",
                "    ${container_response}=    IT COMMON - Gnmi Get And Return    ${container_path}",
                "    ${container}=    IT COMMON - Gnmi Get Leaf Value    ${container_response}    ${container_path}",
                "    IT COMMON - Gnmi Leaf Should Exist    ${container}    alignment-status",
                "    IT COMMON - Gnmi Leaf Should Exist    ${container}    alignment-status-update-time",
                "    Should Be Equal    ${container}[alignment-type]    ${type}",
                "    ${status_response}=    IT COMMON - Gnmi Get And Return    ${status_path}",
                "    ${status}=    IT COMMON - Gnmi Get Leaf Value    ${status_response}    ${status_path}",
                "    IT COMMON - Value Should Be One Of    ${status}    ${allowed_statuses}",
                "    Should Be Equal    ${status}    ${container}[alignment-status]",
                "    ${time_response}=    IT COMMON - Gnmi Get And Return    ${time_path}",
                "    ${time}=    IT COMMON - Gnmi Get Leaf Value    ${time_response}    ${time_path}",
                "    ${is_stamp}=    Evaluate    isinstance($time, str)    modules=builtins",
                "    Should Be True    ${is_stamp}",
                "    Should Be Equal    ${time}    ${container}[alignment-status-update-time]",
                "    IF    $time != ''",
                "        Evaluate    datetime.datetime.fromisoformat($time.replace('Z', '+00:00'))    modules=datetime",
                "    ELSE IF    $status == 'ALIGN_STATUS_ALIGNED'",
                "        Fail    ${type} is ALIGNED but its update time is empty",
                "    END",
                "END",
            ],
            vars=[("allowed_statuses", ALIGNMENT_STATUSES)],
        ),
    ],
)

S(
    "ALN-014",
    bench=True,
    sheet="ALIGNMENT",
    area=GRPC_CAL,
    comment="The gRPC calibration service in its auto, semi-auto and manual modes",
    doc="Verify the gRPC calibration service in AUTO, SEMI_AUTO and MANUAL "
        "modes plus GetCalibrationStatus; StartCalibration is a streaming RPC "
        "that reports the progress of every stage (User Guide 12.1.2).",
    vars=[
        ("proto", "calibration.proto"),
        ("start_method", "gnoi.calibration.v1.Calibration/StartCalibration"),
        ("status_method", "gnoi.calibration.v1.Calibration/GetCalibrationStatus"),
        ("ALN014_CALIBRATION_BLOCKED", "${FALSE}"),
    ],
    cases=[
        C(
            "Start the calibration in auto mode over gRPC",
            doc=[
                "Step 1. Call StartCalibration with mode AUTO",
                "Step 2. Check ordered stage progress and final SUCCESS",
            ],
            tags=["GRPC", "WRITE"],
            log="1_auto.log",
            vars=[("payload", '{"mode": "AUTO"}')],
            body=[
                "VAR    ${ALN014_CALIBRATION_BLOCKED}    ${TRUE}    scope=SUITE",
                "${response}=    IT COMMON - Grpcurl And Return Json List    ${proto}    ${start_method}    ${payload}    timeout=600",
                "GrpcJson.Check Calibration Stream    ${response}    AUTO",
                "VAR    ${ALN014_CALIBRATION_BLOCKED}    ${FALSE}    scope=SUITE",
            ],
        ),
        C(
            "Start the calibration in semi-auto mode over gRPC",
            doc=[
                "Step 1. Call StartCalibration with mode SEMI_AUTO and startStage STAGE_DS1",
                "Step 2. Check ordered progress and SUCCESS or a manual adjustment stop",
            ],
            tags=["GRPC", "WRITE"],
            log="2_semi_auto.log",
            vars=[("payload", '{"mode": "SEMI_AUTO", "startStage": "STAGE_DS1"}')],
            body=[
                "IF    $ALN014_CALIBRATION_BLOCKED    Skip    Previous calibration did not complete successfully; inspect its result before starting another.",
                "VAR    ${ALN014_CALIBRATION_BLOCKED}    ${TRUE}    scope=SUITE",
                "${response}=    IT COMMON - Grpcurl And Return Json List    ${proto}    ${start_method}    ${payload}    timeout=600",
                "${outcome}=    GrpcJson.Check Calibration Stream    ${response}    SEMI_AUTO",
                "Log    Semi-auto outcome: ${outcome}",
                "IF    $outcome == 'SUCCESS'",
                "    VAR    ${ALN014_CALIBRATION_BLOCKED}    ${FALSE}    scope=SUITE",
                "END",
            ],
        ),
        C(
            "Start the calibration in manual mode over gRPC",
            doc=[
                "Step 1. Call StartCalibration with mode MANUAL and startStage STAGE_DS1",
                "Step 2. Check DS1 is the only stage and the stream ends in SUCCESS",
            ],
            tags=["GRPC", "WRITE"],
            log="3_manual.log",
            vars=[("payload", '{"mode": "MANUAL", "startStage": "STAGE_DS1"}')],
            body=[
                "IF    $ALN014_CALIBRATION_BLOCKED    Skip    Previous calibration failed or requires manual adjustment; inspect its result before starting another.",
                "${response}=    IT COMMON - Grpcurl And Return Json List    ${proto}    ${start_method}    ${payload}    timeout=600",
                "GrpcJson.Check Calibration Stream    ${response}    MANUAL",
            ],
        ),
        C(
            "Read the calibration status over gRPC",
            doc=[
                "Step 1. Call GetCalibrationStatus",
                "Step 2. Check the stage statuses and any manual adjustments",
            ],
            tags=["GRPC"],
            log="4_status.log",
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${status_method}",
                "GrpcJson.Check Calibration Status    ${response}",
            ],
        ),
    ],
)

S(
    "ALN-015",
    sheet="ALIGNMENT",
    area=CONTROL_FLAGS,
    comment="The calibration control flags and parameters, set and get",
    doc="Verify the calibration control flags and parameters that affect the "
        "calibration behaviour (auto_adj_legacy_vatt, ignore_np_ds_calib_adj, "
        "ignore_restore_agc_adj, ignore_reset_fdx_us, station_mode, "
        "interference_ratio_based, single_mode_gain_delta) (User Guide 7.1, "
        "10.6, 10.7, 10.11, 10.12).",
    cases=[
        C(
            "Set and read the RF board calibration flags",
            doc=[
                "Set and read each flag, restoring its original value even on failure.",
            ],
            tags=["CLI", "WRITE"],
            log="rfboard_flags.log",
            body=[
                "FOR    ${flag}    IN    auto_adj_legacy_vatt    ignore_np_ds_calib_adj    ignore_restore_agc_adj    ignore_reset_fdx_us",
                "    ${before}=    IT COMMON - Dut Command Should Succeed    sc_rfboard_cli get_${flag}",
                "    ${original}=    IT COMMON - Get Cli Field    ${before}    get_${flag}",
                "    Should Match Regexp    ${original}    ^[01]$",
                "    TRY",
                "        ${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_${flag} 1",
                "        Should Contain    ${set}    set_${flag}...success",
                "        ${read}=    IT COMMON - Dut Command Should Succeed    sc_rfboard_cli get_${flag}",
                "        IT COMMON - Cli Field Should Equal    ${read}    get_${flag}    1",
                "        IF    $flag == 'ignore_np_ds_calib_adj'",
                "            ${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_${flag} 0",
                "            Should Contain    ${set}    set_${flag}...success",
                "            ${read}=    IT COMMON - Dut Command Should Succeed    sc_rfboard_cli get_${flag}",
                "            IT COMMON - Cli Field Should Equal    ${read}    get_${flag}    0",
                "        END",
                "    FINALLY",
                "        ${restore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_${flag} ${original}",
                "        Should Contain    ${restore}    set_${flag}...success",
                "        ${read}=    IT COMMON - Dut Command Should Succeed    sc_rfboard_cli get_${flag}",
                "        IT COMMON - Cli Field Should Equal    ${read}    get_${flag}    ${original}",
                "    END",
                "END",
            ],
        ),
        C(
            "Toggle the station mode",
            doc=[
                "Step 1. Read the station mode",
                "Step 2. Set it to with_cable_sim and read it back",
                "Step 3. Set it to normal, then restore the original mode",
            ],
            tags=["CLI", "WRITE"],
            log="station_mode.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode",
                "${original}=    IT COMMON - Get Cli Field    ${before}    station mode",
                "Should Match Regexp    ${original}    ^(normal|with_cable_sim)$",
                "TRY",
                "    FOR    ${mode}    IN    with_cable_sim    normal",
                "        ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_station_mode ${mode}",
                "        Should Be Empty    ${set}",
                "        ${read}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode",
                "        IT COMMON - Cli Field Should Equal    ${read}    station mode    ${mode}",
                "    END",
                "FINALLY",
                "    ${restore}=    IT COMMON - Run Dut Command And Return    sc_cli set_station_mode ${original}",
                "    Should Be Empty    ${restore}",
                "    ${read}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode",
                "    IT COMMON - Cli Field Should Equal    ${read}    station mode    ${original}",
                "END",
            ],
        ),
        C(
            "Set and restore the NAFE ratio",
            doc=[
                "Set the ratio to 3 and restore its full-precision running value.",
            ],
            tags=["CLI", "WRITE"],
            log="nafe_ratio.log",
            body=[
                "${original}=    IT COMMON - Read Live Nonvol Number    /sercomm/downstream_plus_interference_to_downstream_ratio_based_db",
                "TRY",
                "    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_interference_ratio_based 3",
                "    Should Contain    ${set}    set_interference_ratio_based success",
                "    ${read}=    IT COMMON - Dut Command Should Succeed    sc_cli get_interference_ratio_based",
                "    IT COMMON - Cli Inline Number Should Equal    ${read}    value    3",
                "FINALLY",
                "    ${restore}=    IT COMMON - Run Dut Command And Return    sc_cli set_interference_ratio_based ${original}",
                "    Should Contain    ${restore}    set_interference_ratio_based success",
                "    ${restored}=    IT COMMON - Read Live Nonvol Number    /sercomm/downstream_plus_interference_to_downstream_ratio_based_db",
                "    Should Be Equal As Strings    ${restored}    ${original}",
                "END",
            ],
        ),
        C(
            "Set and restore gain delta using sc_cli",
            doc=["Set gain delta through sc_cli and restore its original value."],
            tags=["CLI", "WRITE"],
            log="gain_delta.log",
            body=[
                "${original}=    IT COMMON - Read Live Nonvol Number    /alignment/single_mode_gain_delta",
                "TRY",
                "    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_single_mode_gain_delta 1",
                "    Should Contain    ${set}    set_single_mode_gain_delta success",
                "    ${read}=    IT COMMON - Dut Command Should Succeed    sc_cli get_single_mode_gain_delta",
                "    IT COMMON - Cli Inline Number Should Equal    ${read}    value    1",
                "FINALLY",
                "    ${restore}=    IT COMMON - Run Dut Command And Return    sc_cli set_single_mode_gain_delta ${original}",
                "    Should Contain    ${restore}    set_single_mode_gain_delta success",
                "    ${restored}=    IT COMMON - Read Live Nonvol Number    /alignment/single_mode_gain_delta",
                "    Should Be Equal As Strings    ${restored}    ${original}",
                "END",
            ],
        ),
    ],
)
