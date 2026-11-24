*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The NP DS EQ worksheet
Documentation    CHANGELIST | ALIGNMENT
...              The NP DS equalization of the worksheet is updated (DZ300-1912).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-019-1]Run the round two fingerprint of the 1.2G band
    [Documentation]
    ...              Step 1. Set the two tilt anchors
    ...              Step 2. Apply the equalization adjustment
    ...              Step 3. Read the tilts back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_fingerprint.log    scope=TEST
    ${eq4_before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0
    ${eq4}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 4 1.53
    ${eq5}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -10.88
    ${adjust}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli adjust_np_ds_eqs 0.905    timeout=60
    Log    ${adjust}
    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0
    Log    ${after}
    Should Contain    ${after}    NP_DS_VCEQ
    Should Contain    ${after}    NP_DS_INVERSE_EQ

[CL-019-2]Probe the granularity of the EQ5 lookup table
    [Documentation]
    ...              Step 1. Set the five values of the probe
    ...              Step 2. Read the value back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_granularity.log    scope=TEST
    ${v1}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -9.00
    ${v2}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -8.50
    ${v3}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -8.03
    ${v4}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -7.50
    ${v5}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -7.00
    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 5
    Log    ${after}
    Should Contain    ${after}    NP_DS_INVERSE_EQ
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
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
