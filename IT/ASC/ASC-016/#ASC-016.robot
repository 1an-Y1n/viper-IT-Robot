*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The NP US state machine tracks the eCM TX power
Documentation    ASC | Algorithm flowchart
...              Verify that the NP US round tracks the eCM TX power (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-016-1]Check that the eCM is online and that the NP US machine is there
    [Documentation]
    ...              Step 1. Check that the eCM is operational
    ...              Step 2. Read the legacy flag and the eCM tracking flag of the AGC
    ...              Step 3. Read the NP US state machine
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_np_us.log    scope=TEST
    ${cm}=    IT COMMON - Run Dut Command And Return    sc_cli get_snmp_cm_status
    Log    ${cm}
    Should Contain    ${cm}    eCM is OPERATIONAL
    ${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${legacy}=    IT COMMON - Get Cli Field    ${agc}    Legacy enable
    ${track}=    IT COMMON - Get Cli Field    ${agc}    Track eCM power enable
    Log    ${legacy}
    Log    ${track}
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us
    Log    ${status}
    ${fsm}=    IT COMMON - Get Cli Field    ${status}    fsm
    Should Be Equal    ${fsm}    NpUs
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
