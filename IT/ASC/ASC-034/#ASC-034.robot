*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The configuration and the snapshot survive a restart of the daemon
Documentation    ASC | Robustness
...              Verify that the configuration and the snapshot survive a restart of the sc-asc daemon (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-034-1]Read the configuration before the restart
    [Documentation]
    ...              Step 1. Read the ASC and the AGC configuration
    ...              Step 2. Restart the sc-asc daemon
    ...              Step 3. Read the configuration again, it has to be the same
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_restart.log    scope=TEST
    ${asc_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${agc_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${restart}=    IT COMMON - Run Dut Command And Return    systemctl restart sc-asc    timeout=60
    Log    ${restart}
    Sleep    10
    ${asc_after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${agc_after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    Log    ${asc_after}
    Should Be Equal    ${asc_after}    ${asc_before}
    Should Be Equal    ${agc_after}    ${agc_before}
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
