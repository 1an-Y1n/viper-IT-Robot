*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The telemetry entries are generated and persisted
Documentation    ASC | Telemetry
...              Verify that the telemetry entries are generated and persisted (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-023-1]Check the telemetry file and the telemetry over gNMI
    [Documentation]
    ...              Step 1. Check that /mnt/sc_nonvol/agc_telemetry_data.json exists and parses
    ...              Step 2. Read the telemetry over gNMI
    [Tags]    FILE    GNMI
    VAR    ${sc_log}    ${case_name}-1_telemetry.log    scope=TEST
    ${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/agc_telemetry_data.json    timeout=60
    Should Not Be Equal    ${size}    0
    ${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/agc_telemetry_data.json
    Should Not Be Equal    ${parsed}    ${EMPTY}
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
