*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Switch the ASC between Disable, FreeRun and Monitor
Documentation    ASC | OperationMode
...              Verify that switching between Disable, FreeRun and Monitor is clean (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-006-1]Switch from Disable to FreeRun
    [Documentation]
    ...              Step 1. Set the operation mode to Disable and read it back
    ...              Step 2. Set the operation mode to FreeRun and read it back
    ...              Step 3. Read the ADU status
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_disable_to_free_run.log    scope=TEST
    ${disable}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0
    ${disabled_config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Should Contain    ${disabled_config}    operationMode = Disable
    ${free_run}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Should Contain    ${config}    operationMode = FreeRun
    ${adu}=    IT COMMON - Run Dut Command And Return    sc_cli get_adu_status
    Log    ${adu}

[ASC-006-2]Switch from FreeRun to Monitor and back
    [Documentation]
    ...              Step 1. Set the operation mode to Monitor and read it back
    ...              Step 2. Set the operation mode to Disable and read it back
    ...              Step 3. Set the operation mode to FreeRun and read it back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_free_run_to_monitor.log    scope=TEST
    ${monitor}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 2
    ${monitor_config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Should Contain    ${monitor_config}    operationMode = Monitor
    ${disable}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0
    ${disabled_config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Should Contain    ${disabled_config}    operationMode = Disable
    ${free_run}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Should Contain    ${config}    operationMode = FreeRun
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
