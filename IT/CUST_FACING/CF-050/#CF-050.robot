*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set the north port switch path over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Get and set the np_monitor_input over gNMI (User Guide 9.2.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-050-1]SET the north port switch path over gNMI
    [Documentation]
    ...              Step 1. GET the switch path
    ...              Step 2. SET it to upstream and then to downstream
    ...              Step 3. Compare the result with sc_rfboard_cli
    [Tags]    GNMI    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_set.log    scope=TEST
    VAR    @{updates}    /rf-components/north-port-switch-path:::string:::NP_SWITCH_UPSTREAM    /rf-components/north-port-switch-path:::string:::NP_SWITCH_DOWNSTREAM
    VAR    @{paths}    /rf-components/north-port-switch-path
    ${before}=    IT COMMON - Gnmi Get And Return    /rf-components/north-port-switch-path
    ${set_up}=    IT COMMON - Gnmi Set And Return    ${{['/rf-components/north-port-switch-path:::string:::NP_SWITCH_UPSTREAM']}}
    Log    ${set_up}
    ${set_down}=    IT COMMON - Gnmi Set And Return    ${{['/rf-components/north-port-switch-path:::string:::NP_SWITCH_DOWNSTREAM']}}
    Log    ${set_down}
    Should Contain    ${set_down}    UPDATE
    ${after}=    IT COMMON - Gnmi Get And Return    /rf-components/north-port-switch-path
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    /rf-components/north-port-switch-path
    Log    ${value}
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_np_monitor_input
    Log    ${cli}
    Should Contain    ${cli}    downstream
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
