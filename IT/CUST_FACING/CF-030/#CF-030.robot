*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The CM LED
Documentation    CUST_FACING | LED Tests
...              Using the sc_led CLI, verify the on and the off state of the CM LED (User Guide 1.3).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-030-1]Turn the CM LED on and off
    [Documentation]
    ...              Step 1. Turn the cm LED on
    ...              Step 2. Turn the cm LED off again
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_cm.log    scope=TEST
    ${on}=    IT COMMON - Run Fdx Command And Return    sc_led -l cm -c green -o on
    Log    ${on}
    ${off}=    IT COMMON - Run Fdx Command And Return    sc_led -l cm -c green -o off
    Log    ${off}
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
