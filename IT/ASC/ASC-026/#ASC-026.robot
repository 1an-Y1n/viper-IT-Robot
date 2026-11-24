*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The NP clipping events are detected and reported
Documentation    ASC | Clipping Monitor
...              Verify that the NP clipping events are detected and reported (User Guide 10.4). The overload signal is injected with the bench.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-026-1]Read the clipping state and the clip counter
    [Documentation]
    ...              Step 1. Read the clipping interval of the ASC
    ...              Step 2. Read the clipping state machine
    ...              Step 3. Read the clip counter of the north port
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_clipping.log    scope=TEST
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${interval}=    IT COMMON - Get Cli Field    ${config}    clippingInterval
    Log    ${interval}
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status clipping
    Log    ${status}
    ${fsm}=    IT COMMON - Get Cli Field    ${status}    fsm
    Should Be Equal    ${fsm}    Clipping
    ${port}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_port_status 0
    ${count}=    IT COMMON - Get Cli Field    ${port}    rx_adc_clip_count
    Log    ${count}
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
