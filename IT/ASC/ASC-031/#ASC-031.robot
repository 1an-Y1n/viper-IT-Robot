*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The ASC rounds do not start while the MGC holds the RF board
Documentation    ASC | Gating
...              Verify that the ASC rounds do not start while the MGC controller preempts the right to use the RF board (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-031-1]Read the MSC controller and the bypass decision
    [Documentation]
    ...              Step 1. Read the MSC state and the MSC controller
    ...              Step 2. Read the bypass controller decision
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_msc.log    scope=TEST
    ${state}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_state
    ${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller
    ${bypass}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_bypass_controller_decision
    Log    ${state}
    Log    ${controller}
    Log    ${bypass}
    Should Contain    ${state}    MSC state:
    Should Contain    ${controller}    MSC controller:
    Should Contain    ${bypass}    Bypass controller decision:

[ASC-031-2]Hold the RF board with the MSC controller and read the ASC
    [Documentation]
    ...              Step 1. Hand the RF board over to the ASC controller (index 3)
    ...              Step 2. Read the ASC configuration and the state machines
    ...              Step 3. Give the RF board back to nobody (index 0)
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_preempt.log    scope=TEST
    ${set}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_msc_controller 3
    ${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller
    Log    ${controller}
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    Log    ${status}
    ${release}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_msc_controller 0
    ${after}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller
    Log    ${after}
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
