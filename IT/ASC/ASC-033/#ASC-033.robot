*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The loops stop during the calibration and resume after it
Documentation    ASC | Gating
...              Verify that the loops stop during the calibration and resume after the calibration data store (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-033-1]Raise the calibration required flag and read the ASC
    [Documentation]
    ...              Step 1. Read the calibration required flag
    ...              Step 2. Raise it
    ...              Step 3. Read the state of the four state machines
    ...              Step 4. Clear the flag again
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_calibration_gate.log    scope=TEST
    VAR    @{fsms}    sp_ds    np_ds    clipping    np_us
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag
    Log    ${before}
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_calib_req_config_flag true
    ${sp_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status sp_ds
    ${np_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    ${clipping}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status clipping
    ${np_us}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us
    FOR    ${fsm}    IN    @{fsms}
        ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled
        Log    ${state}
    END
    ${clear}=    IT COMMON - Run Dut Command And Return    sc_cli set_calib_req_config_flag false
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag
    Should Contain    ${after}    flag: false
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
