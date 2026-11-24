*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The US FDX DAC power mode over gRPC
Documentation    CUST_FACING | GRPC Tests
...              Verify that the gRPC US FDX DAC service can read and set the DAC power mode (User Guide 12.1.5).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    us_fdx_dac.proto
${get_method}    gnoi.us_fdx_dac.v1.UsFdxDacController/GetUsFdxDacPowerModeVolatile
${set_method}    gnoi.us_fdx_dac.v1.UsFdxDacController/SetUsFdxDacPowerModeVolatile
*** Test Cases ***
[CF-055-1]GET the DAC power mode over gRPC
    [Documentation]
    ...              Step 1. Call GetUsFdxDacPowerModeVolatile
    ...              Step 2. The answer has to hold the mode
    [Tags]    GRPC
    VAR    ${sc_log}    ${case_name}-1_get.log    scope=TEST
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    Log    ${response}

[CF-055-2]SET the DAC power mode over gRPC
    [Documentation]
    ...              Step 1. SET the mode to ENABLED
    ...              Step 2. SET the mode to DISABLED
    ...              Step 3. GET the mode again
    [Tags]    GRPC    WRITE
    VAR    ${sc_log}    ${case_name}-2_set.log    scope=TEST
    VAR    ${enabled}    {"mode": "ENABLED"}
    VAR    ${disabled}    {"mode": "DISABLED"}
    ${on}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${enabled}
    Log    ${on}
    ${off}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${disabled}
    Log    ${off}
    ${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
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
