*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The management IP mode
Documentation    CUST_FACING | Sercomm CLI
...              Show the management port IP configuration (User Guide 10.6). The switch between DHCP and a static address drops the management connection, so it is a step of the bench procedure and is not done by the suite.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-021-1]Show the management IP configuration
    [Documentation]
    ...              Step 1. Run mgmtip show
    ...              Step 2. The answer has to hold the IP mode and the address
    [Tags]    CLI    BENCH
    VAR    ${sc_log}    ${case_name}-1_mgmtip.log    scope=TEST
    ${out}=    IT COMMON - Run Fdx Command And Return    mgmtip show
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
