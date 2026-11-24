*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The SP DS state machine corrects the output side drift
Documentation    ASC | Algorithm flowchart
...              Verify that the SP DS round corrects the output side drift (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-015-1]Read the state of the SP DS machine
    [Documentation]
    ...              Step 1. Read the SP DS state machine
    ...              Step 2. Check that it carries the five fields of the state
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_sp_ds.log    scope=TEST
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status sp_ds
    Log    ${status}
    ${fsm}=    IT COMMON - Get Cli Field    ${status}    fsm
    Should Be Equal    ${fsm}    SpDs
    ${stage}=    IT COMMON - Get Cli Field    ${status}    current_stage
    Should Not Be Equal    ${stage}    ${EMPTY}
    ${running}=    IT COMMON - Get Cli Field    ${status}    running_status
    Should Not Be Equal    ${running}    ${EMPTY}
    ${loops}=    IT COMMON - Get Cli Field    ${status}    loop_count
    Should Not Be Equal    ${loops}    ${EMPTY}

[ASC-015-2]Read the attenuation table of the RF board
    [Documentation]
    ...              Step 1. GET the attenuation table of the RF board
    ...              Step 2. Check that the eight attenuation entries are there
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_attenuation.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
    Log    ${out}
    Should Contain    ${out}    NP_DS_ATT_BEFORE_LNA
    Should Contain    ${out}    NP_DS_ATT_BETWEEN_LNAS
    Should Contain    ${out}    NP_DS_ATT_AFTER_LNA
    Should Contain    ${out}    US_FDX_IN_ATT
    Should Contain    ${out}    US_FDX_OUT_ATT
    Should Contain    ${out}    US_LEGACY_ATT_BEFORE_LNA
    Should Contain    ${out}    US_LEGACY_ATT_AFTER_LNA
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
