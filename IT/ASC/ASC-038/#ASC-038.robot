*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read and set the ASC configuration over gRPC
Documentation    ASC | GRPC Configuration Service
...              Use grpcurl to GET and SET the ASC configuration through the gRPC AscConfigService, then verify the values with sc_cli get_asc_config (User Guide 12.1.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    asc_config.proto
${get_method}    gnoi.asc_config.v1.AscConfigService/GetAscConfiguration
${set_method}    gnoi.asc_config.v1.AscConfigService/SetAscConfiguration
*** Test Cases ***
[ASC-038-1]SET the ASC configuration over gRPC and read it back
    [Documentation]
    ...              Step 1. Save all eleven original fields
    ...              Step 2. Set the template configuration over gRPC
    ...              Step 3. Compare every field through gRPC and sc_cli
    ...              Step 4. Restore and verify all original fields
    [Tags]    GRPC    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-2_set.log    scope=TEST
    VAR    ${payload}    {"ascConfig": {"enable": 1, "inputInterval": 120, "outputInterval": 600, "clippingInterval": 1, "inputPowerTransientThreshold": 0.5, "deltaPilotDiffThreshold": 0.7, "maxPositiveAdjustment": 4.0, "maxNegativeAdjustment": -4.0, "firstPilotFrequency": 261000000, "secondPilotFrequency": 711000000, "thirdPilotFrequency": 903000000}}
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    IT COMMON - Grpc Should Succeed    ${response}
    ${original}=    IT COMMON - Grpc Get Field    ${response}    ascConfig
    IT ASC - Grpc And CLI Configuration Should Equal    ${original}
    ${restore_payload}=    Evaluate    json.dumps({'ascConfig': $original})    modules=json
    ${expected}=    Evaluate    json.loads($payload)['ascConfig']    modules=json
    TRY
        ${set}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${payload}
        IT COMMON - Grpc Should Succeed    ${set}
        Wait Until Keyword Succeeds    120s    5s    IT ASC - Grpc And CLI Configuration Should Equal    ${expected}
    FINALLY
        ${restore}=    Run Keyword And Continue On Failure    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${restore_payload}
        Run Keyword And Continue On Failure    IT COMMON - Grpc Should Succeed    ${restore}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Grpc And CLI Configuration Should Equal    ${original}
    END
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
    # the suite has nothing to clean up
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
