*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read the PAB status over gRPC and cross check it with the CLI
Documentation    PAB | GRPC Configuration, Status & Control
...              Request the PAB status with grpcurl and check the pabStatus object (User Guide 12.1.4.3).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    pab_config.proto
${method}    gnoi.pab_config.v1.PabConfig/GetPabStatus
*** Test Cases ***
[PAB-011-1]GET the PAB status over gRPC
    [Documentation]
    ...              Step 1. Wait until the PAB has completed a round
    ...              Step 2. Call GetPabStatus
    ...              Step 3. Check that the call succeeded
    ...              Step 4. Check the fields of the pabStatus object
    [Tags]    GRPC
    VAR    ${sc_log}    ${case_name}-1_grpc.log    scope=TEST
    ${response}=    IT COMMON - Wait For Grpc Nested Field Value
    ...    ${proto}    ${method}
    ...    ${{['pabStatus', 'isCompleted']}}    True
    ...    timeout=180    interval=5
    IT COMMON - Grpc Should Succeed    ${response}
    ${status}=    IT COMMON - Grpc Get Field    ${response}    pabStatus
    IT COMMON - Grpc Field Should Exist    ${status}    enabled
    IT COMMON - Grpc Field Should Exist    ${status}    isCompleted
    IT COMMON - Grpc Field Should Exist    ${status}    loopCount
    IT COMMON - Grpc Field Should Exist    ${status}    ecmOnline
    IT COMMON - Grpc Field Should Exist    ${status}    runningMode
    IT COMMON - Grpc Field Should Exist    ${status}    currentStage
    IT COMMON - Grpc Field Should Exist    ${status}    runningStatus

[PAB-011-2]Cross check the gRPC status with the CLI
    [Documentation]
    ...              Step 1. GET the PAB status with sc_cli
    ...              Step 2. Compare the mode, the stage and the running status of both answers
    [Tags]    GRPC    CLI
    VAR    ${sc_log}    ${case_name}-2_grpc_cli.log    scope=TEST
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}
    ${status}=    IT COMMON - Grpc Get Field    ${response}    pabStatus
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    ${cli_mode}=    IT COMMON - Get Cli Field    ${cli}    Running Mode
    ${grpc_mode}=    IT COMMON - Grpc Get Field    ${status}    runningMode
    IT COMMON - Grpc Enum Should Match Cli    ${grpc_mode}    ${cli_mode}
    ${cli_stage}=    IT COMMON - Get Cli Field    ${cli}    Current Stage
    ${grpc_stage}=    IT COMMON - Grpc Get Field    ${status}    currentStage
    IT COMMON - Grpc Enum Should Match Cli    ${grpc_stage}    ${cli_stage}
    ${cli_running}=    IT COMMON - Get Cli Field    ${cli}    Running Status
    ${grpc_running}=    IT COMMON - Grpc Get Field    ${status}    runningStatus
    IT COMMON - Grpc Enum Should Match Cli    ${grpc_running}    ${cli_running}
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
