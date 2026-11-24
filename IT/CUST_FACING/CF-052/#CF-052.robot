*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Reboot the DUT over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Reboot the device with a gNMI SET (User Guide 9.17). The reboot is a step of the bench procedure, so the suite sends the request and reads the system status afterwards.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-052-1]Read the system status before the reset
    [Documentation]
    ...              Step 1. GET system-status
    ...              Step 2. The answer has to hold the reboot info
    [Tags]    GNMI    BENCH
    VAR    ${sc_log}    ${case_name}-1_status.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    system-status
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    system-status
    Log    ${value}
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
