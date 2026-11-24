*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Enable and disable the AGC
Documentation    CUST_FACING | Sercomm CLI
...              Verify the AGC enable and disable through set_asc_config operationMode and the AGC log output (User Guide 8.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-022-1]Enable the AGC and check that it runs
    [Documentation]
    ...              Step 1. Set the log level of the AGC to debug
    ...              Step 2. Read the AGC and the ASC configuration
    ...              Step 3. Set the operation mode to FreeRun
    ...              Step 4. Read the ASC configuration back
    ...              Step 5. Clear the calibration required flag so that the AGC runs
    ...              Step 6. Read the state of the four state machines
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_enable.log    scope=TEST
    VAR    @{fsms}    sp_ds    np_ds    clipping    np_us
    ${log}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 7
    Log    ${log}
    ${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${asc_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
    ${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Should Contain    ${asc}    operationMode = FreeRun
    ${flag}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag
    Log    ${flag}
    ${clear}=    IT COMMON - Run Dut Command And Return    sc_cli set_calib_req_config_flag false
    ${sp_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status sp_ds
    ${np_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    ${clipping}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status clipping
    ${np_us}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us
    FOR    ${fsm}    IN    @{fsms}
        ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled
        Log    ${state}
    END

[CF-022-2]Disable the AGC and check that it is refused to start
    [Documentation]
    ...              Step 1. Set the operation mode to Disable
    ...              Step 2. Try to start the AGC control, it has to be refused
    ...              Step 3. Set the log level of the AGC back to info
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_disable.log    scope=TEST
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0
    ${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Should Contain    ${asc}    operationMode = Disable
    ${start}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start
    Log    ${start}
    Should Not Contain    ${start}    Success
    ${log}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 6
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
