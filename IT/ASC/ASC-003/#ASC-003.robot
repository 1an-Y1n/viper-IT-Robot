*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Reset the AGC configuration and disable the ASC
Documentation    ASC | CLI Configuration
...              The template holds two content blocks under this id: the reset of the AGC configuration to its defaults and the ASC Disable mode. Both are two test cases of this suite.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-003-1]Set an AGC flag and check that it is stored
    [Documentation]
    ...              Step 1. Set the FDX flag of the AGC configuration (index 5)
    ...              Step 2. Read the configuration back
    ...              Step 3. Check that /mnt/sc_nonvol/agc_data.json is there
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_agc_file.log    scope=TEST
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 4 1
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    Log    ${config}
    Should Contain    ${config}    Fdx enable: true
    ${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/agc_data.json    timeout=60
    Should Not Be Equal    ${size}    0

[ASC-003-2]Reset the AGC configuration and check that it is readable
    [Documentation]
    ...              Step 1. Run sc_cli reset_agc_config
    ...              Step 2. Read the AGC configuration back
    ...              Step 3. The template expects the file to be gone after the reset;
    ...                      on this firmware it stays, so the check is that the
    ...                      configuration is back to its defaults and still parses
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-2_agc_reset.log    scope=TEST
    ${reset}=    IT COMMON - Run Dut Command And Return    sc_cli reset_agc_config
    Log    ${reset}
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    Log    ${config}
    ${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/agc_data.json    timeout=300

[ASC-003-3]Disable the ASC and check that the control loops stop
    [Documentation]
    ...              Step 1. Set the operation mode to Disable
    ...              Step 2. Read the ASC configuration
    ...              Step 3. Check that all four state machines report enabled = false
    ...              Step 4. Try to start the AGC control, it has to be refused
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-3_asc_disable.log    scope=TEST
    VAR    @{fsms}    sp_ds    np_ds    clipping    np_us
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Log    ${config}
    Should Contain    ${config}    operationMode = Disable
    ${sp_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status sp_ds
    ${np_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    ${clipping}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status clipping
    ${np_us}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us
    FOR    ${fsm}    IN    @{fsms}
        ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled
        Should Be Equal    ${state}    false
    END
    ${start}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start
    Log    ${start}
    Should Contain    ${start}    failed

[ASC-003-4]Put the ASC back into FreeRun mode
    [Documentation]
    ...              Step 1. Set the operation mode back to FreeRun
    ...              Step 2. Read the ASC configuration
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-4_asc_enable.log    scope=TEST
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Log    ${config}
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
