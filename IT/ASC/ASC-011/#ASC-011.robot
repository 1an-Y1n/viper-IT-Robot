*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Reset the AGC and the ASC configuration to their defaults
Documentation    ASC | Config/Target Data clear
...              Verify that reset_agc resets the agc_config and the asc_config to their defaults and clears the calibration snapshot (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-011-1]Reset the AGC configuration and check it
    [Documentation]
    ...              Step 1. Change the ASC configuration and the AGC configuration
    ...              Step 2. Run sc_cli reset_agc
    ...              Step 3. Read both configurations back, they have to be the defaults
    ...              Step 4. Run show again, the snapshot has to be cleared
    [Tags]    CLI    FILE    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_reset.log    scope=TEST
    ${set_asc}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 300
    ${set_agc}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 1 0.5
    ${reset}=    IT COMMON - Run Dut Command And Return    sc_cli reset_agc
    Log    ${reset}
    Should Contain    ${reset}    calibration snapshot cleared
    ${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Log    ${asc}
    ${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    Log    ${agc}
    ${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    Log    ${show}
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
