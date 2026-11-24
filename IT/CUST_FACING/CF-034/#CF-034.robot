*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read the capabilities of the gNMI server
Documentation    CUST_FACING | GNMI Tests
...              Basic sanity check that the gNMI is working (User Guide 9.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-034-1]Read the capabilities of the gNMI server
    [Documentation]
    ...              Step 1. Run gnmic capabilities
    ...              Step 2. The answer has to list the models of the server
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_capabilities.log    scope=TEST
    ${raw}=    IT COMMON - Gnmi Capabilities And Return
    Log    ${raw}
    Should Contain    ${raw}    gNMI version
    Should Contain    ${raw}    supported models
    Should Contain    ${raw}    supported encodings
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
