*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Trigger the PAB control STOP over gRPC and check the status
Documentation    PAB | GRPC Configuration, Status & Control
...              Trigger the pre-alignment balancing procedure with the STOP command of the gRPC API (User Guide 12.1.4.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    pab_config.proto
${method}    gnoi.pab_config.v1.PabConfig/SetPabCommand
${get_method}    gnoi.pab_config.v1.PabConfig/GetPabStatus
*** Test Cases ***
[PAB-014-1]Send the STOP command over gRPC
    [Documentation]
    ...              Step 1. Start a round, so that the STOP has something to stop
    ...              Step 2. Call SetPabCommand with STOP
    ...              Step 3. Check that the call succeeded
    [Tags]    GRPC    WRITE
    VAR    ${sc_log}    ${case_name}-1_grpc.log    scope=TEST
    VAR    ${payload}    {"pabCommand": {"currentCommand": "STOP"}}
    VAR    ${stop_payload}    {"pabCommand": {"currentCommand": "STOP"}}
    VAR    ${start_payload}    {"pabCommand": {"currentCommand": "START"}}
    ${start}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${start_payload}
    IT COMMON - Grpc Should Succeed    ${start}
    ${running}=    IT COMMON - Wait For Dut Cli Field Different    sc_cli get_pab_status    Current Stage    IDLE    timeout=60    interval=1
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}
    IT COMMON - Grpc Should Succeed    ${response}
    ${success}=    IT COMMON - Grpc Get Field    ${response}    success
    ${status}=    IT COMMON - Grpc Get Field    ${success}    status
    Should Be Equal    ${status}    SUCCESS

[PAB-014-2]Check the PAB status after the STOP command
    [Documentation]
    ...              Step 1. Wait until the PAB shows that the command took
    ...              Step 2. Check the running mode of the gRPC answer
    ...              Step 3. Cross check the running mode with sc_cli get_pab_status
    ...              Step 4. The template expects the stage to be STAGE1 right after the
    ...                      command, but the stage walks on by itself, so the stage is
    ...                      not pinned to one value here
    [Tags]    GRPC    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_grpc_cli.log    scope=TEST
    VAR    ${mode_suffix}    STOP
    VAR    ${cli_mode_suffix}    STOP
    ${cli}=    IT COMMON - Wait For Dut Cli Field    sc_cli get_pab_status    Running Mode    ${cli_mode_suffix}    timeout=120    interval=1
    ${cli_mode}=    IT COMMON - Get Cli Field    ${cli}    Running Mode
    Should Be Equal    ${cli_mode}    ${cli_mode_suffix}
    ${cli_stage}=    IT COMMON - Get Cli Field    ${cli}    Current Stage
    Should Be Equal    ${cli_stage}    IDLE
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    IT COMMON - Grpc Should Succeed    ${response}
    ${status}=    IT COMMON - Grpc Get Field    ${response}    pabStatus
    ${mode}=    IT COMMON - Grpc Get Field    ${status}    runningMode
    Should Be Equal    ${mode}    ALIGN_PAB_MODE_${mode_suffix}

[PAB-014-3]Check that the PAB is at rest
    [Documentation]
    ...              Step 1. GET the PAB status
    ...              Step 2. The stage has to be IDLE and the procedure has to be
    ...                      at rest
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-3_cli.log    scope=TEST
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    ${stage}=    IT COMMON - Get Cli Field    ${status}    Current Stage
    Should Be Equal    ${stage}    IDLE
    ${running}=    IT COMMON - Get Cli Field    ${status}    Running Status
    Should Be Equal    ${running}    DONE
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
