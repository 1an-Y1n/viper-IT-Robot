*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The Sercomm master control commands
Documentation    CUST_FACING | MSC (sc_msc_cli)
...              Verify the nine sc_msc_cli commands that arbitrate the RF board controller (User Guide 10.14).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-061-1]Read the MSC state, the controller, the statistics and the timeout
    [Documentation]
    ...              Step 1. Read the MSC state
    ...              Step 2. Read the MSC controller
    ...              Step 3. Read the MSC statistics
    ...              Step 4. Read the MGC timeout
    ...              Step 5. Read the bypass controller decision
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_read.log    scope=TEST
    ${state}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_state
    ${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller
    ${stats}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_stats
    ${timeout}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_mgc_timeout
    ${bypass}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_bypass_controller_decision
    Log    ${state}
    Log    ${controller}
    Log    ${stats}
    Log    ${timeout}
    Log    ${bypass}
    Should Contain    ${state}    MSC state:
    Should Contain    ${controller}    MSC controller:
    Should Contain    ${stats}    successful_forwards
    Should Contain    ${timeout}    MGC timeout:
    Should Contain    ${bypass}    Bypass controller decision:

[CF-061-2]Set the MGC timeout and put it back
    [Documentation]
    ...              Step 1. Read the MGC timeout
    ...              Step 2. Set it to 300 s and read it back
    ...              Step 3. Put the original value back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_timeout.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_mgc_timeout
    ${old}=    IT COMMON - Get Cli Field    ${before}    MGC timeout
    ${set}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_mgc_timeout 300
    ${after}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_mgc_timeout
    Log    ${after}
    Should Contain    ${after}    300
    ${back}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_mgc_timeout ${old}

[CF-061-3]Toggle the bypass controller decision
    [Documentation]
    ...              Step 1. Set the bypass controller decision to 1 and read it back
    ...              Step 2. Set it back to 0 and read it back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-3_bypass.log    scope=TEST
    ${on}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_bypass_controller_decision 1
    ${on_state}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_bypass_controller_decision
    Log    ${on_state}
    Should Contain    ${on_state}    enabled
    ${off}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_bypass_controller_decision 0
    ${off_state}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_bypass_controller_decision
    Log    ${off_state}
    Should Contain    ${off_state}    disabled
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
