*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The north AFE backoff
Documentation    CUST_FACING | Sercomm CLI
...              Verify the north AFE backoff configuration through sc_cli get and set_north_afe_back_off (User Guide 10.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-020-1]Read and set the north AFE backoff
    [Documentation]
    ...              Step 1. Read the current backoff
    ...              Step 2. Set it to 16.5 dB
    ...              Step 3. Read it back
    ...              Step 4. Put the original value back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_backoff.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_afe_back_off
    ${old}=    IT COMMON - Get Cli Field    ${before}    afe
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_north_afe_back_off 16.5
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_afe_back_off
    Log    ${after}
    IT COMMON - Cli Number Should Equal    ${after}    afe    16.5
    ${back}=    IT COMMON - Run Dut Command And Return    sc_cli set_north_afe_back_off ${old}
    ${restored}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_afe_back_off
    IT COMMON - Cli Number Should Equal    ${restored}    afe    ${old}
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
