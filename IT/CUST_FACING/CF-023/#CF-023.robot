*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The firmware upgrade
Documentation    CUST_FACING | Sercomm CLI
...              Upgrade the firmware through the Comcast CLI over HTTP or through the Broadcom brcmupgrade CLI (User Guide 11.1, 11.2). The upgrade itself is a step of the bench procedure, so the suite reads the version that is in place.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-023-1]Read the firmware version of the DUT
    [Documentation]
    ...              Step 1. Read the version file of the DUT
    ...              Step 2. Read the version through the clish
    ...              Step 3. Both have to carry the same software version
    [Tags]    CLI    FILE    BENCH
    VAR    ${sc_log}    ${case_name}-1_version.log    scope=TEST
    ${file}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt
    Log    ${file}
    ${clish}=    IT COMMON - Run Fdx Command And Return    show version
    Log    ${clish}
    Should Contain    ${clish}    Software Version
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
