*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The near clipping guardrail of the NP port
Documentation    ASC | Clipping Monitor
...              Verify the near-clipping warning threshold and the guardrail configuration (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-027-1]Read the clipping guardrail of the AGC and change it
    [Documentation]
    ...              Step 1. Read the NP clipping guardrail
    ...              Step 2. Set it to 3 dB and read it back
    ...              Step 3. Put it back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_guardrail.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${old}=    IT COMMON - Get Cli Field    ${before}    NP Clipping Guardrail
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 9 3
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    Log    ${after}
    IT COMMON - Cli Number Should Equal    ${after}    NP Clipping Guardrail    3
    ${back}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 9 ${old}
    ${restored}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    IT COMMON - Cli Number Should Equal    ${restored}    NP Clipping Guardrail    ${old}
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
