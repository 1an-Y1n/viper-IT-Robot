*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Non FDX alignment, Legacy Mid-Split
Documentation    ALIGNMENT | FDX & Non-FDX Alignment
...              Set the ds-profile, the us-profile and the spectrum allocation to Non-FDX (Legacy Mid-Split), run the PAB FreeRun and the Non-FDX alignment flow DS1 -> DS2 -> DS3 -> US (User Guide 5.2, 7.1, 7.2.1). The DUT is rebooted between the configuration and the PAB, which is a step of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${ALN_LINEUP_FAILED}    ${FALSE}
*** Test Cases ***
[ALN-003-1]Configure the north port ds-profile
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
    ${start_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    start-freq 120000000
    ${start_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    start-power 31.8
    ${end_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    end-freq 1002000000
    ${end_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    end-power 45.0
    ${step}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    step-down 0 start-freq 1002000000
    ${size}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    step-down 0 size-db 0.0
    ${before}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    show configuration
    ${commit}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    commit
    Should Contain    ${commit}    applied local configuration
    ${after}=    IT COMMON - Run Fdx View Command And Return    ds-profile-north    show configuration
    ${exit}=    IT COMMON - Fdx Exit View    ds-profile-north
    ${actual_name}=    IT COMMON - Get Clish Field    ${after}    name
    Should Be Equal    ${actual_name}    profile-3
    IT COMMON - Clish Number Should Equal    ${after}    start-freq    120000000
    IT COMMON - Clish Number Should Equal    ${after}    start-power    31.8
    IT COMMON - Clish Number Should Equal    ${after}    end-freq    1002000000
    IT COMMON - Clish Number Should Equal    ${after}    end-power    45.0
    IT COMMON - Clish Number Should Equal    ${after}    step-index:0 start-freq    1002000000
    IT COMMON - Clish Number Should Equal    ${after}    step-index:0 size-db    0
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}

[ALN-003-2]Configure the south port ds-profile
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
    ${start_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    start-freq 120000000
    ${start_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    start-power 31.8
    ${end_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    end-freq 1002000000
    ${end_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    end-power 45.0
    ${step}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    step-down 0 start-freq 1002000000
    ${size}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    step-down 0 size-db 0.0
    ${before}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    show configuration
    ${commit}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    commit
    Should Contain    ${commit}    applied local configuration
    ${after}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    show configuration
    ${exit}=    IT COMMON - Fdx Exit View    ds-profile-south
    ${actual_name}=    IT COMMON - Get Clish Field    ${after}    name
    Should Be Equal    ${actual_name}    profile-3
    IT COMMON - Clish Number Should Equal    ${after}    start-freq    120000000
    IT COMMON - Clish Number Should Equal    ${after}    start-power    31.8
    IT COMMON - Clish Number Should Equal    ${after}    end-freq    1002000000
    IT COMMON - Clish Number Should Equal    ${after}    end-power    45.0
    IT COMMON - Clish Number Should Equal    ${after}    step-index:0 start-freq    1002000000
    IT COMMON - Clish Number Should Equal    ${after}    step-index:0 size-db    0
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}

[ALN-003-3]Set the legacy RLSP of both ports
    [Documentation]
    ...              Step 1. Read the legacy RLSP of both ports
    ...              Step 2. Set both to 8 dBmV
    ...              Step 3. Read them back
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-legacy_rlsp.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${TRUE}
    ${before_north}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp north
    ${before_south}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp south
    ${set_north}=    IT COMMON - Run Dut Command And Return    sc_cli set_legacy_rlsp north 8
    ${set_south}=    IT COMMON - Run Dut Command And Return    sc_cli set_legacy_rlsp south 8
    ${north}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp north
    ${south}=    IT COMMON - Run Dut Command And Return    sc_cli get_legacy_rlsp south
    Log    ${north}
    Should Contain    ${north}    North Port rlsp: 8.000000 dBmv
    Should Contain    ${south}    South Port rlsp: 8.000000 dBmv
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}

[ALN-003-4]Apply the Legacy Mid-Split spectrum allocation
    [Documentation]
    ...              Step 1. Enter the spectrum view
    ...              Step 2. Set the downstream and the legacy upstream range
    ...              Step 3. Remove the three subbands, the current version has a
    ...                      minimum subband number limitation
    ...              Step 4. Remove the frequency exclusions, the preset below has
    ...                      none and the commit refuses the allocation as long as
    ...                      one of them is there
    ...              Step 5. Apply the Legacy_MidSplit_DS_1.2GHz preset and commit it
    ...              Step 6. Check the allocation over sc_cli
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-spectrum.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${TRUE}
    ${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum
    ${ds_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-start-freq 108000000
    ${ds_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-end-freq 1218000000
    ${us_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-start-freq 5000000
    ${us_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-end-freq 85000000
    ${ext_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-start-freq 0
    ${ext_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-end-freq 0
    ${rm0}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband remove 0
    ${rm1}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband remove 1
    ${rm2}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband remove 2
    ${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
    ${exclusions}=    IT COMMON - Get Count After Label    ${before}    Total frequency exclusions
    Log    ${before}
    FOR    ${index}    IN RANGE    ${exclusions}
        ${rm_excl}=    IT COMMON - Run Fdx View Command And Return    spectrum    remove freq-exclusion ${index}
    END
    ${preset}=    IT COMMON - Run Fdx View Command And Return    spectrum    debug sc_cli set_spectrum_allocation Legacy_MidSplit_DS_1.2GHz
    ${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit    timeout=120
    Should Contain    ${commit}    applied local configuration
    ${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
    ${exit}=    IT COMMON - Fdx Exit View    spectrum
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_spectrum_allocation
    Log    ${cli}
    Should Contain    ${cli}    description: Legacy_MidSplit_DS_1.2GHz
    Should Contain    ${cli}    dsBeginHz: 108000000
    Should Contain    ${cli}    dsEndHz: 1218000000
    Should Contain    ${cli}    usExtendedBeginHz: 0
    Set Suite Variable    ${ALN_LINEUP_FAILED}    ${FALSE}

[ALN-003-5]Set the configuration state to MID_SPLIT
    [Documentation]
    ...              Step 1. Set the configuration state
    ...              Step 2. GET configuration-status over gNMI
    ...              Step 3. Check that the spectrum state is MID_SPLIT
    ...              Step 4. GET configuration-status/spectrum-state over gNMI
    [Tags]    CLI    GNMI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-configuration_state.log    scope=TEST
    VAR    ${state}    MID_SPLIT
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

[ALN-003-6]Reboot the DUT and wait for it to come back
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

[ALN-003-7]Check the spectrum state after the reboot
    [Documentation]
    ...              Step 1. GET configuration-status over gNMI
    ...              Step 2. The spectrum state has to be MID_SPLIT
    ...              Step 3. GET configuration-status/spectrum-state over gNMI
    [Tags]    GNMI    BENCH
    VAR    ${sc_log}    ${case_name}-spectrum_state_after_reboot.log    scope=TEST
    VAR    ${state}    MID_SPLIT
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

[ALN-003-8]Run the PAB FreeRun round
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

[ALN-003-9]Allow the calibration to adjust the attenuations
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

[ALN-003-10]Run the alignment stages ds1, ds2, ds3, us
    [Documentation]
    ...              Step 1. Enter the alignment view
    ...              Step 2. Run the stages in order: ds1, ds2, ds3, us
    ...              Step 3. Show the alignment status
    ...              Step 4. Leave the view
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-alignment_ds1_ds2_ds3_us.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${enter}=    IT COMMON - Fdx Enter View    configure alignment    alignment
    ${ds1}=    IT COMMON - Run Fdx View Command And Return    alignment    start-ds1    timeout=300
    Should Contain    ${ds1}    Completed DS1 alignment
    ${ds2}=    IT COMMON - Run Fdx View Command And Return    alignment    start-ds2    timeout=300
    Should Contain    ${ds2}    Completed DS2 alignment
    ${ds3}=    IT COMMON - Run Fdx View Command And Return    alignment    start-ds3    timeout=300
    Should Contain    ${ds3}    Completed DS3 alignment
    ${us}=    IT COMMON - Run Fdx View Command And Return    alignment    start-us    timeout=300
    Should Contain    ${us}    Completed US alignment
    ${status}=    IT COMMON - Run Fdx View Command And Return    alignment    show alignment-status
    Log    ${status}
    Should Contain    ${status}    DS1:ALIGNED    msg=the DS1 stage is not aligned, the answer was: ${status}
    Should Contain    ${status}    DS2:ALIGNED    msg=the DS2 stage is not aligned, the answer was: ${status}
    Should Contain    ${status}    DS3:ALIGNED    msg=the DS3 stage is not aligned, the answer was: ${status}
    Should Contain    ${status}    US:ALIGNED    msg=the US stage is not aligned, the answer was: ${status}
    ${action}=    IT COMMON - Run Fdx View Command And Return    alignment    show alignment-action
    ${exit}=    IT COMMON - Fdx Exit View    alignment
    Log    ${action}

[ALN-003-11]Adjust the JXP tilt and the US DAC
    [Documentation]
    ...              Step 1. Read the JXP tilt of the RF board
    ...              Step 2. Disable the US DAC so that it does not affect the FDX US path
    ...              Step 3. Set the US FDX out attenuation
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-jxp_dac.log    scope=TEST
    IF    $ALN_LINEUP_FAILED
        Skip    A preceding lineup configuration failed; dependent steps must not run.
    END
    ${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt
    Log    ${jxp}
    Should Contain    ${jxp}    get_legacy_up_jxp_tilt =
    ${dac}=    IT COMMON - Run Dut Hal Command And Return    /leap/np_dac_power_mode_set 0 0
    Log    ${dac}
    Should Contain    ${dac}    Successfully set NP-DAC power mode
    ${atten}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_attenuation 5 31.5
    Log    ${atten}

[ALN-003-12]Clear the calibration required flag
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
