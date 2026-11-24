*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Show the version of the device and of every AMP module
Documentation    CUST_FACING | Comcast CLI
...              Display the device information and the version of every AMP module (User Guide 3.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-008-1]Show the version of the device
    [Documentation]
    ...              Step 1. Run show version
    ...              Step 2. Check the six fields of the answer
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_version.log    scope=TEST
    ${out}=    IT COMMON - Run Fdx Command And Return    show version
    Log    ${out}
    Should Contain    ${out}    Device Type
    Should Contain    ${out}    Hardware Version
    Should Contain    ${out}    Part Number / Revision
    Should Contain    ${out}    Software Version
    Should Contain    ${out}    Number Of Components
    Should Contain    ${out}    System Uptime

[CF-008-2]Show the version of every AMP module
    [Documentation]
    ...              Step 1. Run show version details
    ...              Step 2. The answer has to hold the details of the modules
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_version_details.log    scope=TEST
    ${out}=    IT COMMON - Run Fdx Command And Return    show version details
    Log    ${out}
    Should Not Be Equal    ${out}    ${EMPTY}
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
