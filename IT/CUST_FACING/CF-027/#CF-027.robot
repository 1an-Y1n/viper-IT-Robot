*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The ICS button, pressed twice
Documentation    CUST_FACING | LED Tests
...              Press the ICS button twice: 16 dB attenuation, the mode times out after 20 minutes and the second ICS LED turns on (User Guide 1.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-027-1]Read the state of the LEDs after two presses of the ICS button
    [Documentation]
    ...              Step 1. The ICS button was pressed twice
    ...              Step 2. Read the attenuation of the RF board
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_ics16.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
    Log    ${out}
    Should Contain    ${out}    US_FDX_OUT_ATT
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
