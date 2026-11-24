*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The gNMI containers that have no test case of their own
Documentation    CUST_FACING | GNMI Tests
...              Verify the gNMI containers that have no dedicated test case, focusing on the field semantics (User Guide 9.5, 9.6, 9.7, 9.8, 9.13, 9.14, 9.15, 9.17).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-053-1]GET the twelve containers that have no test case of their own
    [Documentation]
    ...              Step 1. GET every container
    ...              Step 2. Every answer has to hold a value
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_containers.log    scope=TEST
    VAR    @{paths}    wbfft-capture    north-port-status    south-port-status    north-port-monitor-status    system-status    extended-upstream-spectrum-status    fallback-status    segment-allocation    ds-monitor-data    configuration-status    configuration-status/spectrum-state
    @{missing}=    Create List
    FOR    ${path}    IN    @{paths}
        ${response}=    IT COMMON - Gnmi Get And Return    ${path}
        ${value}=    IT COMMON - Gnmi Get Leaf Value Or Default    ${response}    ${path}    ${NONE}
        IF    $value is None
            Append To List    ${missing}    ${path}
        ELSE
            Log    ${value}
            Should Not Be Equal    ${value}    ${EMPTY}
        END
    END
    IF    ${missing}
        Fail    The gNMI server does not have these containers: ${missing}
    END

[CF-053-2]Check the spectrum state of the configuration status
    [Documentation]
    ...              Step 1. GET configuration-status/spectrum-state
    ...              Step 2. The value has to be one of the four known states
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-2_spectrum_state.log    scope=TEST
    VAR    @{states}    MID_SPLIT    FDX_PENDING    FDX_COARSE    FDX_FINE
    ${response}=    IT COMMON - Gnmi Get And Return    configuration-status/spectrum-state
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    configuration-status/spectrum-state
    Log    ${value}
    IT COMMON - Value Should Be One Of    ${value}    ${states}
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
