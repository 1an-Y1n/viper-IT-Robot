*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The loops stay stopped until the PAB is over
Documentation    ASC | Gating
...              Verify that the loops stay stopped until the PAB completes (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-032-1]Stop the PAB and read the ASC
    [Documentation]
    ...              Step 1. Stop the PAB
    ...              Step 2. Read the PAB status
    ...              Step 3. Read the state of the four state machines
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_pab_gate.log    scope=TEST
    VAR    @{fsms}    sp_ds    np_ds    clipping    np_us
    ${stop}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control stop
    ${pab}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    Log    ${pab}
    ${sp_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status sp_ds
    ${np_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    ${clipping}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status clipping
    ${np_us}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us
    FOR    ${fsm}    IN    @{fsms}
        ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled
        Log    ${state}
    END

[ASC-032-2]Start the PAB again
    [Documentation]
    ...              Step 1. Start the PAB in FreeRun mode
    ...              Step 2. Read the PAB status
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_pab_start.log    scope=TEST
    ${run}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control free_run
    Should Contain    ${run}    Success
    ${pab}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    Log    ${pab}
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
