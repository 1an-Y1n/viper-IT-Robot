*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The clipping monitor default interval is two seconds
Documentation    CHANGELIST | ASC
...              The clipping monitor default interval is raised to two seconds and the calibration snapshot carries two new keys (DZ300-1918).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-008-1]Check the clipping interval of the ASC
    [Documentation]
    ...              Step 1. Read the clipping interval of the ASC
    ...              Step 2. It has to be two seconds
    ...              Step 3. Look for the clipping lines of the syslog
    [Tags]    CLI    FILE
    VAR    ${sc_log}    ${case_name}-1_clipping.log    scope=TEST
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${interval}=    IT COMMON - Get Cli Field    ${config}    clippingInterval
    Log    ${interval}
    Should Be Equal    ${interval}    2
    ${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'UpdateControlData' /dev/shm/syslog | tail -n 3
    Log    ${syslog}

[CL-008-2]Check the two new keys of the calibration snapshot
    [Documentation]
    ...              Step 1. Dump the calibration snapshot
    ...              Step 2. Check that the dump holds the two new keys
    [Tags]    CLI    FILE
    VAR    ${sc_log}    ${case_name}-2_snapshot.log    scope=TEST
    VAR    ${dump_file}    /tmp/cl008_snapshot.json
    ${dump}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot dump ${dump_file}    timeout=120
    Log    ${dump}
    ${size}=    IT COMMON - Wait For File On Dut    ${dump_file}    timeout=60
    Should Not Be Equal    ${size}    0
    ${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    Log    ${show}
    Should Contain    ${show}    np_f_reference_spectrum
    Should Contain    ${show}    fdx_path_gain_cal
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
