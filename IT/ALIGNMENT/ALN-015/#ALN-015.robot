*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The calibration control flags and parameters, set and get
Documentation    ALIGNMENT | Calibration Control Flags
...              Verify the calibration control flags and parameters that affect the calibration behaviour (auto_adj_legacy_vatt, ignore_np_ds_calib_adj, ignore_restore_agc_adj, ignore_reset_fdx_us, station_mode, interference_ratio_based, single_mode_gain_delta) (User Guide 7.1, 10.6, 10.7, 10.11, 10.12).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ALN-015-1]Set and read the RF board calibration flags
    [Documentation]
    ...              Set and read each flag, restoring its original value even on failure.
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-rfboard_flags.log    scope=TEST
    FOR    ${flag}    IN    auto_adj_legacy_vatt    ignore_np_ds_calib_adj    ignore_restore_agc_adj    ignore_reset_fdx_us
        ${before}=    IT COMMON - Dut Command Should Succeed    sc_rfboard_cli get_${flag}
        ${original}=    IT COMMON - Get Cli Field    ${before}    get_${flag}
        Should Match Regexp    ${original}    ^[01]$
        TRY
            ${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_${flag} 1
            Should Contain    ${set}    set_${flag}...success
            ${read}=    IT COMMON - Dut Command Should Succeed    sc_rfboard_cli get_${flag}
            IT COMMON - Cli Field Should Equal    ${read}    get_${flag}    1
            IF    $flag == 'ignore_np_ds_calib_adj'
                ${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_${flag} 0
                Should Contain    ${set}    set_${flag}...success
                ${read}=    IT COMMON - Dut Command Should Succeed    sc_rfboard_cli get_${flag}
                IT COMMON - Cli Field Should Equal    ${read}    get_${flag}    0
            END
        FINALLY
            ${restore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_${flag} ${original}
            Should Contain    ${restore}    set_${flag}...success
            ${read}=    IT COMMON - Dut Command Should Succeed    sc_rfboard_cli get_${flag}
            IT COMMON - Cli Field Should Equal    ${read}    get_${flag}    ${original}
        END
    END

[ALN-015-2]Toggle the station mode
    [Documentation]
    ...              Step 1. Read the station mode
    ...              Step 2. Set it to with_cable_sim and read it back
    ...              Step 3. Set it to normal, then restore the original mode
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-station_mode.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode
    ${original}=    IT COMMON - Get Cli Field    ${before}    station mode
    Should Match Regexp    ${original}    ^(normal|with_cable_sim)$
    TRY
        FOR    ${mode}    IN    with_cable_sim    normal
            ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_station_mode ${mode}
            Should Be Empty    ${set}
            ${read}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode
            IT COMMON - Cli Field Should Equal    ${read}    station mode    ${mode}
        END
    FINALLY
        ${restore}=    IT COMMON - Run Dut Command And Return    sc_cli set_station_mode ${original}
        Should Be Empty    ${restore}
        ${read}=    IT COMMON - Run Dut Command And Return    sc_cli get_station_mode
        IT COMMON - Cli Field Should Equal    ${read}    station mode    ${original}
    END

[ALN-015-3]Set and restore the NAFE ratio
    [Documentation]
    ...              Set the ratio to 3 and restore its full-precision running value.
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-nafe_ratio.log    scope=TEST
    ${original}=    IT COMMON - Read Live Nonvol Number    /sercomm/downstream_plus_interference_to_downstream_ratio_based_db
    TRY
        ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_interference_ratio_based 3
        Should Contain    ${set}    set_interference_ratio_based success
        ${read}=    IT COMMON - Dut Command Should Succeed    sc_cli get_interference_ratio_based
        IT COMMON - Cli Inline Number Should Equal    ${read}    value    3
    FINALLY
        ${restore}=    IT COMMON - Run Dut Command And Return    sc_cli set_interference_ratio_based ${original}
        Should Contain    ${restore}    set_interference_ratio_based success
        ${restored}=    IT COMMON - Read Live Nonvol Number    /sercomm/downstream_plus_interference_to_downstream_ratio_based_db
        Should Be Equal As Strings    ${restored}    ${original}
    END

[ALN-015-4]Set and restore gain delta using sc_cli
    [Documentation]
    ...              Set gain delta through sc_cli and restore its original value.
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-gain_delta.log    scope=TEST
    ${original}=    IT COMMON - Read Live Nonvol Number    /alignment/single_mode_gain_delta
    TRY
        ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_single_mode_gain_delta 1
        Should Contain    ${set}    set_single_mode_gain_delta success
        ${read}=    IT COMMON - Dut Command Should Succeed    sc_cli get_single_mode_gain_delta
        IT COMMON - Cli Inline Number Should Equal    ${read}    value    1
    FINALLY
        ${restore}=    IT COMMON - Run Dut Command And Return    sc_cli set_single_mode_gain_delta ${original}
        Should Contain    ${restore}    set_single_mode_gain_delta success
        ${restored}=    IT COMMON - Read Live Nonvol Number    /alignment/single_mode_gain_delta
        Should Be Equal As Strings    ${restored}    ${original}
    END
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
