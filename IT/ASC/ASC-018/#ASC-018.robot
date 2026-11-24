*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The SP DS rounds run at the configured interval
Documentation    ASC | Interval
...              Verify that the SP DS rounds run at the configured interval (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-018-1]Read the SP DS interval and change it
    [Documentation]
    ...              Step 1. Read the output interval of the ASC
    ...              Step 2. Set it to 900 s and read it back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_interval.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${old}=    IT COMMON - Get Cli Field    ${before}    outputInterval
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config outputInterval 900
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    IT COMMON - Cli Number Should Equal    ${after}    outputInterval    900

[ASC-018-2]Put the original interval back
    [Documentation]
    ...              Step 1. Put the output interval back
    ...              Step 2. Read the configuration
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_restore.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${old}=    IT COMMON - Get Cli Field    ${before}    outputInterval
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config outputInterval ${old}
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    IT COMMON - Cli Number Should Equal    ${after}    outputInterval    ${old}
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
