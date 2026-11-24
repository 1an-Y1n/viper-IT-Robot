*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set the AGC configuration and read it back
Documentation    ASC | CLI Configuration
...              Verify that the AGC tuning configuration can be set and read back over sc_cli. The reboot and the factory reset are steps of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-002-1]Enable the legacy flag and the eCM tracking of the AGC
    [Documentation]
    ...              Step 1. Read the AGC configuration
    ...              Step 2. Set the legacy flag (index 4) and the eCM tracking (index 8)
    ...              Step 3. Read the configuration back and check both flags
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_agc_config.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${legacy_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 3 1
    ${ecm_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 8 1
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    Log    ${after}
    Should Contain    ${after}    Legacy enable: true
    Should Contain    ${after}    Track eCM power enable: true

[ASC-002-2]Put the original AGC configuration back
    [Documentation]
    ...              Step 1. Read the values that were in place before the case
    ...              Step 2. Put the legacy flag and the eCM tracking back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_restore.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${legacy}=    IT COMMON - Get Cli Field    ${before}    Legacy enable
    ${ecm}=    IT COMMON - Get Cli Field    ${before}    Track eCM power enable
    ${legacy_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 3 0
    ${ecm_set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 8 0
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
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
