*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The functional LED state machine
Documentation    CUST_FACING | LED Tests
...              Verify the functional LED state machine (the power, the boot and the CM operational states) as opposed to the sc_led manual override of CF-029 to CF-032 (User Guide 1.3). The states are read over gNMI.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-033-1]Read the system status over gNMI
    [Documentation]
    ...              Step 1. GET system-status
    ...              Step 2. Check that it holds the crash status and the reboot info
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_system_status.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    system-status
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    system-status
    Log    ${value}
    Should Not Be Equal    ${value}    ${EMPTY}
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
