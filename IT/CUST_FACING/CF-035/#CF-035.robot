*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Walk the whole data tree
Documentation    CUST_FACING | GNMI Tests
...              Retrieve the entire data tree over gNMI (User Guide 9.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-035-1]Walk the whole data tree
    [Documentation]
    ...              Step 1. GET the whole tree
    ...              Step 2. The answer has to hold the top level containers
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_walk.log    scope=TEST
    ${raw}=    IT COMMON - Gnmi Get Raw    ${EMPTY}    timeout=120
    Log    ${raw}
    Should Contain    ${raw}    amp-identification
    Should Contain    ${raw}    pab-result
    Should Contain    ${raw}    system-status
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
