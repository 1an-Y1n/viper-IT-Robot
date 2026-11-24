*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Partial FDX alignment with dummy DS energy
Documentation    ALIGNMENT | FDX & Non-FDX Alignment
...              Set the ds-profile, the us-profile and the spectrum allocation to Partial FDX with Dummy DS Energy (the three subbands are bidi and the frequency exclusion is added), run the PAB FreeRun, the FDX calibration flow, the NAFE calibration and the second pass (User Guide 5.4, 7.1, 7.2.2). The AUTO calibration is not used here, the stages are run manually the way the workaround of the User Guide says. The DUT is rebooted twice, which is a step of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${ALN_LINEUP_FAILED}    ${FALSE}
*** Test Cases ***
[ALN-006-1]Configure the north port ds-profile
    [Documentation]
    ...              Step 1. Enter the ds-profile view of the north port
    ...              Step 2. Set the name and the frequency / power range
    ...              Step 3. Show the configuration and commit it
    ...              Step 4. Leave the view
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-north_ds_profile.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${TRUE}
    ${enter}=    IT COMMON - Fdx Enter View    configure ds-profile north    ds-profile-north
    ${name}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    name profile-3
    ${start_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    start-freq 108000000
    ${start_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    start-power 31.8
    ${end_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    end-freq 1098000000
    ${end_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    end-power 46.4
    ${step}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    step-down 0 start-freq 1002000000
    ${size}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    step-down 0 size-db 0.0
    ${before}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    show configuration
    ${commit}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    commit
    Should Contain    ${commit}    applied local configuration
    ${after}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    show configuration
    ${exit}=    IT COMMON - Fdx Exit View    ds-profile-north
    ${actual_name}=    IT COMMON - Get Clish Field    ${after}    name
    Should Be Equal    ${actual_name}    profile-3
    IT COMMON - Clish Number Should Equal    ${after}    start-freq    108000000
    IT COMMON - Clish Number Should Equal    ${after}    start-power    31.8
    IT COMMON - Clish Number Should Equal    ${after}    end-freq    1098000000
    IT COMMON - Clish Number Should Equal    ${after}    end-power    46.4
    IT COMMON - Clish Number Should Equal    ${after}    step-index:0 start-freq    1002000000
    IT COMMON - Clish Number Should Equal    ${after}    step-index:0 size-db    0
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}

[ALN-006-2]Configure the south port ds-profile
    [Documentation]
    ...              Step 1. Enter the ds-profile view of the south port
    ...              Step 2. Set the name and the frequency / power range
    ...              Step 3. Show the configuration and commit it
    ...              Step 4. Leave the view
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-south_ds_profile.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${TRUE}
    ${enter}=    IT COMMON - Fdx Enter View    configure ds-profile south    ds-profile-south
    ${name}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    name profile-3
    ${start_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    start-freq 108000000
    ${start_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    start-power 31.8
    ${end_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    end-freq 1098000000
    ${end_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    end-power 46.4
    ${step}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    step-down 0 start-freq 1002000000
    ${size}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    step-down 0 size-db 0.0
    ${before}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    show configuration
    ${commit}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    commit
    Should Contain    ${commit}    applied local configuration
    ${after}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    show configuration
    ${exit}=    IT COMMON - Fdx Exit View    ds-profile-south
    ${actual_name}=    IT COMMON - Get Clish Field    ${after}    name
    Should Be Equal    ${actual_name}    profile-3
    IT COMMON - Clish Number Should Equal    ${after}    start-freq    108000000
    IT COMMON - Clish Number Should Equal    ${after}    start-power    31.8
    IT COMMON - Clish Number Should Equal    ${after}    end-freq    1098000000
    IT COMMON - Clish Number Should Equal    ${after}    end-power    46.4
    IT COMMON - Clish Number Should Equal    ${after}    step-index:0 start-freq    1002000000
    IT COMMON - Clish Number Should Equal    ${after}    step-index:0 size-db    0
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}

[ALN-006-3]Set the RLSP of the us-profiles and of the legacy ports
    [Documentation]
    ...              Step 1. Set the rlsp of the north and the south us-profile
    ...              Step 2. Set the legacy rlsp of both ports
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-us_profile.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${TRUE}
    ${enter_north}=    IT COMMON - Fdx Enter View    configure us-profile north    us-profile-north
    ${rlsp_north}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    rlsp 8.0
    ${commit_north}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    commit
    Should Contain    ${commit_north}    applied local configuration
    ${after_north}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    show configuration
    ${exit_north}=    IT COMMON - Fdx Exit View    us-profile-north
    ${enter_south}=    IT COMMON - Fdx Enter View    configure us-profile south    us-profile-south
    ${rlsp_south}=    IT COMMON - Run Fdx View Command And Return    us-profile-south    rlsp 8.0
    ${commit_south}=    IT COMMON - Run Fdx View Command And Return    us-profile-south    commit
    Should Contain    ${commit_south}    applied local configuration
    ${after_south}=    IT COMMON - Run Fdx View Command And Return    us-profile-south    show configuration
    ${exit_south}=    IT COMMON - Fdx Exit View    us-profile-south
    ${legacy_north}=    IT COMMON - Run Dut Command And Return    sc_cli set_legacy_rlsp north 8
    Should Contain    ${legacy_north}    Set legacy rlsp Success
    ${legacy_south}=    IT COMMON - Run Dut Command And Return    sc_cli set_legacy_rlsp south 8
    Should Contain    ${legacy_south}    Set legacy rlsp Success
    IT COMMON - Clish Number Should Equal    ${after_north}    rlsp    8
    IT COMMON - Clish Number Should Equal    ${after_south}    rlsp    8
    ${get_north}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp north
    ${get_south}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp south
    IT COMMON - Cli Number Should Equal    ${get_north}    North Port rlsp    8
    IT COMMON - Cli Number Should Equal    ${get_south}    South Port rlsp    8
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}

[ALN-006-4]Configure the spectrum allocation
    [Documentation]
    ...              Step 1. Enter the spectrum view
    ...              Step 2. Set the downstream, the legacy upstream and the extended upstream range
    ...              Step 3. Add missing subbands if needed and set their modes
    ...              Step 4. Show the configuration
    ...              Step 5. Add the frequency exclusion
    ...              Step 6. Commit it and leave the view
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-spectrum.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${TRUE}
    ${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum
    TRY
        ${initial}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
        ${subband_count}=    IT COMMON - Get Count After Label    ${initial}    Total subbands
        Should Be True    $subband_count <= 3    Spectrum has more than three subbands; refusing to remove any.
        FOR    ${index}    IN RANGE    ${subband_count}
            ${existing}=    IT COMMON - Get Clish Field    ${initial}    subBand:${index} mode
        END
        FOR    ${index}    IN RANGE    ${subband_count}    3
            ${add}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband add bidi
            Should Contain    ${add}    successfully added mode bidi
        END
        ${prepared}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
        IT COMMON - Clish Number Should Equal    ${prepared}    Total subbands    3
        FOR    ${index}    IN RANGE    3
            ${existing}=    IT COMMON - Get Clish Field    ${prepared}    subBand:${index} mode
        END
        ${ds_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-start-freq 108000000
        Should Contain    ${ds_start}    is set from
        ${ds_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-end-freq 1218000000
        Should Contain    ${ds_end}    is set from
        ${us_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-start-freq 5000000
        Should Contain    ${us_start}    is set from
        ${us_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-end-freq 85000000
        Should Contain    ${us_end}    is set from
        ${ext_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-start-freq 108000000
        Should Contain    ${ext_start}    is set from
        ${ext_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-end-freq 396000000
        Should Contain    ${ext_end}    is set from
        ${sub0}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 0 bidi
        Should Contain    ${sub0}    is set from
        ${sub1}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 1 bidi
        Should Contain    ${sub1}    is set from
        ${sub2}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 2 bidi
        Should Contain    ${sub2}    is set from
        ${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
        ${exclusions}=    IT COMMON - Get Count After Label    ${before}    Total frequency exclusions
        Log    ${before}
        FOR    ${index}    IN RANGE    ${exclusions}
            ${rm_excl}=    IT COMMON - Run Fdx View Command And Return    spectrum    remove freq-exclusion ${index}
            Should Contain    ${rm_excl}    successfully deleted
        END
        ${excl}=    IT COMMON - Run Fdx View Command And Return    spectrum    add freq-exclusion 383000000 396000000 PASS_OTHER EXCLUDED
        Should Contain    ${excl}    successfully added
        ${staged}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
        IT COMMON - Clish Number Should Equal    ${staged}    ds-start-freq    108000000
        IT COMMON - Clish Number Should Equal    ${staged}    ds-end-freq    1218000000
        IT COMMON - Clish Number Should Equal    ${staged}    us-legacy-start-freq    5000000
        IT COMMON - Clish Number Should Equal    ${staged}    us-legacy-end-freq    85000000
        IT COMMON - Clish Number Should Equal    ${staged}    us-extended-start-freq    108000000
        IT COMMON - Clish Number Should Equal    ${staged}    us-extended-end-freq    396000000
        IT COMMON - Clish Number Should Equal    ${staged}    Total subbands    3
        FOR    ${index}    IN RANGE    3
            ${mode}=    IT COMMON - Get Clish Field    ${staged}    subBand:${index} mode
            Should Be Equal    ${mode}    "bidi"
        END
        IT COMMON - Clish Number Should Equal    ${staged}    Total frequency exclusions    1
        IT COMMON - Clish Number Should Equal    ${staged}    Freq-Exclusion:0 start-hz    383000000
        IT COMMON - Clish Number Should Equal    ${staged}    Freq-Exclusion:0 end-hz    396000000
        ${ds_type}=    IT COMMON - Get Clish Field    ${staged}    Freq-Exclusion:0 ds-fe-type
        Should Be Equal    ${ds_type}    PASS_OTHER
        ${us_type}=    IT COMMON - Get Clish Field    ${staged}    Freq-Exclusion:0 us-fe-type
        Should Be Equal    ${us_type}    EXCLUDED
        ${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit    timeout=120
        Should Contain    ${commit}    applied local configuration
        ${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
        IT COMMON - Clish Number Should Equal    ${after}    ds-start-freq    108000000
        IT COMMON - Clish Number Should Equal    ${after}    ds-end-freq    1218000000
        IT COMMON - Clish Number Should Equal    ${after}    us-legacy-start-freq    5000000
        IT COMMON - Clish Number Should Equal    ${after}    us-legacy-end-freq    85000000
        IT COMMON - Clish Number Should Equal    ${after}    us-extended-start-freq    108000000
        IT COMMON - Clish Number Should Equal    ${after}    us-extended-end-freq    396000000
        IT COMMON - Clish Number Should Equal    ${after}    Total subbands    3
        FOR    ${index}    IN RANGE    3
            ${mode}=    IT COMMON - Get Clish Field    ${after}    subBand:${index} mode
            Should Be Equal    ${mode}    "bidi"
        END
        IT COMMON - Clish Number Should Equal    ${after}    Total frequency exclusions    1
        IT COMMON - Clish Number Should Equal    ${after}    Freq-Exclusion:0 start-hz    383000000
        IT COMMON - Clish Number Should Equal    ${after}    Freq-Exclusion:0 end-hz    396000000
        ${ds_type}=    IT COMMON - Get Clish Field    ${after}    Freq-Exclusion:0 ds-fe-type
        Should Be Equal    ${ds_type}    PASS_OTHER
        ${us_type}=    IT COMMON - Get Clish Field    ${after}    Freq-Exclusion:0 us-fe-type
        Should Be Equal    ${us_type}    EXCLUDED
    FINALLY
        ${exit}=    IT COMMON - Fdx Exit View    spectrum
    END
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}

[ALN-006-5]Set the NP SoC target TCP to 29 dBmV
    [Documentation]
    ...              Step 1. Set the NP SoC target TCP to 29 dBmV
    ...              Step 2. Read it back
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-np_soc_target_tcp.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp 29
    ${out}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp
    Log    ${out}
    IT COMMON - Cli Inline Number Should Equal    ${out}    value    29

[ALN-006-6]Set the configuration state to FDX_FINE
    [Documentation]
    ...              Step 1. Set the configuration state
    ...              Step 2. GET configuration-status over gNMI
    ...              Step 3. Check that the spectrum state is FDX_FINE
    ...              Step 4. GET configuration-status/spectrum-state over gNMI
    [Tags]    CLI    GNMI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-configuration_state.log    scope=TEST
    VAR    ${state}    FDX_FINE
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${set}=    IT COMMON - Run Fdx Command And Return    configuration-state ${state}
    Log    ${set}
    Should Contain    ${set}    ${state}
    ${response}=    IT COMMON - Gnmi Get And Return    configuration-status
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    configuration-status
    ${spectrum_state}=    IT COMMON - Get Dict Field    ${value}    spectrum-state
    Should Be Equal    ${spectrum_state}    ${state}
    ${leaf_response}=    IT COMMON - Gnmi Get And Return    configuration-status/spectrum-state
    ${leaf}=    IT COMMON - Gnmi Get Leaf Value    ${leaf_response}    configuration-status/spectrum-state
    Should Be Equal    ${leaf}    ${state}

[ALN-006-7]Reboot the DUT and wait for it to come back
    [Documentation]
    ...              Step 1. Read how long the DUT has been up
    ...              Step 2. Reboot the DUT with the reset command of the clish
    ...              Step 3. Wait until the DUT answers again
    ...              Step 4. Read the age again and check that the DUT really rebooted
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-reboot.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${before}=    IT COMMON - Get Dut Uptime Seconds
    Run Keyword And Ignore Error    IT COMMON - Run Fdx Command And Return    reset
    IT COMMON - Wait For Dut To Come Back    timeout=900    interval=10
    ${after}=    IT COMMON - Get Dut Uptime Seconds
    Should Be True    ${after} < ${before}    msg=the DUT did not reboot, the age of the system went from ${before}s to ${after}s

[ALN-006-8]Check the spectrum state after the reboot
    [Documentation]
    ...              Step 1. GET configuration-status over gNMI
    ...              Step 2. The spectrum state has to be FDX_FINE
    ...              Step 3. GET configuration-status/spectrum-state over gNMI
    [Tags]    GNMI    BENCH
    VAR    ${sc_log}    ${case_name}-spectrum_state_after_reboot.log    scope=TEST
    VAR    ${state}    FDX_FINE
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${response}=    IT COMMON - Gnmi Get And Return    configuration-status
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    configuration-status
    ${spectrum_state}=    IT COMMON - Get Dict Field    ${value}    spectrum-state
    Should Be Equal    ${spectrum_state}    ${state}
    ${leaf_response}=    IT COMMON - Gnmi Get And Return    configuration-status/spectrum-state
    ${leaf}=    IT COMMON - Gnmi Get Leaf Value    ${leaf_response}    configuration-status/spectrum-state
    Should Be Equal    ${leaf}    ${state}

[ALN-006-9]Run the PAB FreeRun round
    [Documentation]
    ...              Step 1. Set the PAB configuration
    ...              Step 2. GET the configuration back
    ...              Step 3. Stop the PAB and start it again in FreeRun
    ...              Step 4. Wait until the round is over
    ...              Step 5. Check that the eCM is operational
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-pab.log    scope=TEST
    VAR    ${lna_mode}    2
    VAR    ${lna_mode_name}    FREE_RUNNING
    VAR    ${target_tcp}    36.00
    VAR    ${rpd_threshold}    -21.78
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${set_cmd}=    Catenate    SEPARATOR=${SPACE}    sc_cli set_pab_config    ${lna_mode}    2.74    ${target_tcp}    60    60    ${rpd_threshold}    6
    ${set_out}=    IT COMMON - Run Dut Command And Return    ${set_cmd}    timeout=30
    Log    ${set_out}
    Should Contain    ${set_out}    Success
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config
    ${mode}=    IT COMMON - Get Cli Field    ${config}    rx adc lna mode
    Should Be Equal    ${mode}    ${lna_mode} (${lna_mode_name})
    IT COMMON - Cli Number Should Equal    ${config}    target tcp    ${target_tcp}
    IT COMMON - Cli Number Should Equal    ${config}    rx adc lna gain    2.74
    IT COMMON - Cli Number Should Equal    ${config}    RPD power threshold    ${rpd_threshold}
    ${stop}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control stop
    Should Contain    ${stop}    Success
    ${run}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control free_run
    Should Contain    ${run}    Success
    ${fields}=    Create List    Running Mode=FREERUN    Completed=Yes    Current Stage=IDLE
    ${status}=    IT COMMON - Wait For Dut Cli Fields    sc_cli get_pab_status    ${fields}    timeout=300    interval=10
    Log    ${status}
    ${ecm}=    IT COMMON - Wait For Dut Command Contains    sc_amphal_cli get_ecm_status    eCM status = Operational    timeout=600    interval=10
    Log    ${ecm}

[ALN-006-10]Allow the calibration to adjust the attenuations
    [Documentation]
    ...              Step 1. Read the four calibration control flags
    ...              Step 2. Allow the NP DS calibration adjustment and the legacy vATT adjustment
    ...              Step 3. Read the flags back
    ...              Step 4. Set the station mode to with_cable_sim
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-calibration_flags.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${ignore_before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj
    ${auto_before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_auto_adj_legacy_vatt
    ${station_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode
    ${ignore_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_np_ds_calib_adj 0
    ${auto_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_auto_adj_legacy_vatt 1
    ${ignore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj
    ${auto}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_auto_adj_legacy_vatt
    Should Contain    ${ignore}    get_ignore_np_ds_calib_adj = 0
    Should Contain    ${auto}    get_auto_adj_legacy_vatt = 1
    ${station_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_station_mode with_cable_sim
    ${station}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode
    Should Contain    ${station}    with_cable_sim

[ALN-006-11]Run the first manual calibration pass
    [Documentation]
    ...              Step 1. Enter the calibration view
    ...              Step 2. Run the DS1 and the DS2 stages in manual mode
    ...              Step 3. Read the input power of the AFE
    ...              Step 4. Set the NP target TCP to the AFE input TCP minus 0.2 dB,
    ...                      at least 23.5 dBmV
    ...              Step 5. Run the DS3 and the US1 stages in manual mode
    ...              Step 6. Show the calibration status and leave the view
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-calibration_manual_1.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration
    ${ds1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds1    timeout=900
    Should Contain    ${ds1}    Result: SUCCESS
    ${ds2}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds2    timeout=900
    Should Contain    ${ds2}    Result: SUCCESS
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_port_status 0 | grep tcp
    Log    ${status}
    ${input_tcp}=    IT COMMON - Get Cli Field    ${status}    rx_adc_input_power_dbmv_tcp
    ${target}=    Evaluate    max(float($input_tcp) - 0.2, 23.5)    modules=builtins
    ${tcp_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp ${target}
    ${tcp}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp
    Log    ${tcp}
    IT COMMON - Cli Inline Number Should Equal    ${tcp}    value    ${target}
    ${ds3}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds3    timeout=900
    Should Contain    ${ds3}    Result: SUCCESS
    ${us1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual us1    timeout=900
    Should Contain    ${us1}    Result: SUCCESS
    ${cal_status}=    IT COMMON - Run Fdx View Command And Return    calibration    show calibration-status
    ${exit}=    IT COMMON - Fdx Exit View    calibration
    Log    ${cal_status}
    Should Contain    ${cal_status}    STAGE_DS1, Status: ALIGNED
    Should Contain    ${cal_status}    STAGE_DS2, Status: ALIGNED
    Should Contain    ${cal_status}    STAGE_DS3, Status: ALIGNED
    Should Contain    ${cal_status}    STAGE_US1, Status: ALIGNED

[ALN-006-12]Adjust the JXP tilt
    [Documentation]
    ...              Step 1. Read the JXP tilt of the RF board
    ...              Step 2. The US legacy calibration assumes a JXP value of 0 dB
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-jxp_tilt.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt
    Log    ${jxp}
    Should Contain    ${jxp}    get_legacy_up_jxp_tilt =

[ALN-006-13]Run the NAFE calibration with the NP DS adjustment disabled
    [Documentation]
    ...              Step 1. Read the JXP tilt of the RF board
    ...              Step 2. Disable the NP DS calibration adjustment
    ...              Step 3. Run the NAFE calibration of both blocks
    ...              Step 4. Enable the NP DS calibration adjustment again
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-nafe_calibration.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt
    TRY
        ${ignore_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_np_ds_calib_adj 1
        ${ignore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj
        Should Contain    ${ignore}    get_ignore_np_ds_calib_adj = 1
        ${calib}=    IT COMMON - Run Dut Command And Return    sc_cli calib_nafe ALLNAFE    timeout=300
        Log    ${calib}
        Should Contain    ${calib}    calib_nafe success
        Should Not Contain    ${calib}    failed
    FINALLY
        ${ignore_back}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_np_ds_calib_adj 0
        ${ignore_after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj
        Should Contain    ${ignore_after}    get_ignore_np_ds_calib_adj = 0
    END

[ALN-006-14]Set the interference ratio and the target TCP
    [Documentation]
    ...              Step 1. Set the interference ratio based to 3 dB
    ...              Step 2. Set the NP SoC target TCP back to 36 dBmV
    ...              Step 3. Read both back
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-nafe_output.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${ratio_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_interference_ratio_based 3
    ${ratio}=    IT COMMON - Run Dut Command And Return    sc_cli get_interference_ratio_based
    Log    ${ratio}
    IT COMMON - Cli Inline Number Should Equal    ${ratio}    value    3
    ${tcp_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp 36
    ${tcp}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp
    Log    ${tcp}
    IT COMMON - Cli Inline Number Should Equal    ${tcp}    value    36

[ALN-006-15]Reboot the DUT and wait for it to come back
    [Documentation]
    ...              Step 1. Read how long the DUT has been up
    ...              Step 2. Reboot the DUT with the reset command of the clish
    ...              Step 3. Wait until the DUT answers again
    ...              Step 4. Read the age again and check that the DUT really rebooted
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-reboot.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${before}=    IT COMMON - Get Dut Uptime Seconds
    Run Keyword And Ignore Error    IT COMMON - Run Fdx Command And Return    reset
    IT COMMON - Wait For Dut To Come Back    timeout=900    interval=10
    ${after}=    IT COMMON - Get Dut Uptime Seconds
    Should Be True    ${after} < ${before}    msg=the DUT did not reboot, the age of the system went from ${before}s to ${after}s

[ALN-006-16]Run the second manual calibration pass
    [Documentation]
    ...              Step 1. Enter the calibration view
    ...              Step 2. Run the DS1 and the DS2 stages in manual mode
    ...              Step 3. Read the input power of the AFE
    ...              Step 4. Set the NP target TCP to the AFE input TCP minus 0.2 dB,
    ...                      at least 23.5 dBmV
    ...              Step 5. Run the DS3 and the US1 stages in manual mode
    ...              Step 6. Show the calibration status and leave the view
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-calibration_manual_2.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration
    ${ds1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds1    timeout=900
    Should Contain    ${ds1}    Result: SUCCESS
    ${ds2}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds2    timeout=900
    Should Contain    ${ds2}    Result: SUCCESS
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_port_status 0 | grep tcp
    Log    ${status}
    ${input_tcp}=    IT COMMON - Get Cli Field    ${status}    rx_adc_input_power_dbmv_tcp
    ${target}=    Evaluate    max(float($input_tcp) - 0.2, 23.5)    modules=builtins
    ${tcp_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp ${target}
    ${tcp}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp
    Log    ${tcp}
    IT COMMON - Cli Inline Number Should Equal    ${tcp}    value    ${target}
    ${ds3}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds3    timeout=900
    Should Contain    ${ds3}    Result: SUCCESS
    ${us1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual us1    timeout=900
    Should Contain    ${us1}    Result: SUCCESS
    ${cal_status}=    IT COMMON - Run Fdx View Command And Return    calibration    show calibration-status
    ${exit}=    IT COMMON - Fdx Exit View    calibration
    Log    ${cal_status}
    Should Contain    ${cal_status}    STAGE_DS1, Status: ALIGNED
    Should Contain    ${cal_status}    STAGE_DS2, Status: ALIGNED
    Should Contain    ${cal_status}    STAGE_DS3, Status: ALIGNED
    Should Contain    ${cal_status}    STAGE_US1, Status: ALIGNED

[ALN-006-17]Clear the calibration required flag
    [Documentation]
    ...              Step 1. Read the calibration required flag
    ...              Step 2. Clear it
    ...              Step 3. Read it back
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-calib_req_flag.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_calib_req_config_flag false
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag
    Log    ${after}
    Should Contain    ${after}    flag: false
*** Keywords ***
Suite Initialization
    log to console  \n\t=== Suite Initialization START ===
    AutomationFlow.automation initial
    SSH_IT_ROOT.Connect    ssh_setting=${SSH_DUT_IT}    level=ROOT    main_log_name=${case_name}-ssh_root.log
    SSH_IT.Connect    ssh_setting=${SSH_DUT_IT}    level=FDX    main_log_name=${case_name}-ssh_fdx.log
    GNMI_IT.Connect    ssh_setting=${SSH_DUT_IT}    gnmi_setting=${GNMI_DUT_IT}    main_log_name=${case_name}-gnmi.log
    log to console  \n\t=== Suite Initialization STOP ===

Suite Teardown
    log to console  \n\t=== Suite Teardown START ===
    # the suite has nothing to clean up
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
