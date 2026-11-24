*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read the PAB configuration over gRPC and cross check it with the CLI
Documentation    PAB | GRPC Configuration, Status & Control
...              Request the PAB configuration with grpcurl and check the pabConfig object (User Guide 12.1.4.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    pab_config.proto
${method}    gnoi.pab_config.v1.PabConfig/GetPabConfiguration
*** Test Cases ***
[PAB-010-1]GET the PAB configuration over gRPC
    [Documentation]
    ...              Step 1. Call GetPabConfiguration
    ...              Step 2. Check that the call succeeded
    ...              Step 3. Check the fields of the pabConfig object
    [Tags]    GRPC
    VAR    ${sc_log}    ${case_name}-1_grpc.log    scope=TEST
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}
    IT COMMON - Grpc Should Succeed    ${response}
    ${config}=    IT COMMON - Grpc Get Field    ${response}    pabConfig
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'rxAdcLnaGain']}}    2.74
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'pabTargetTcp']}}    36.00
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'checkEcmOnlineInterval']}}    60
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'pabRetryInterval']}}    60
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'rpdPwrdThreshold']}}    -21.78
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'outlierThreshold']}}    6.00

[PAB-010-2]Cross check the gRPC configuration with the CLI
    [Documentation]
    ...              Step 1. GET the PAB configuration with sc_cli
    ...              Step 2. Compare the values of both answers
    [Tags]    GRPC    CLI
    VAR    ${sc_log}    ${case_name}-2_grpc_cli.log    scope=TEST
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}
    ${config}=    IT COMMON - Grpc Get Field    ${response}    pabConfig
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config
    IT COMMON - Cli Number Should Equal    ${cli}    rx adc lna gain    ${{$config['rxAdcLnaGain']}}
    IT COMMON - Cli Number Should Equal    ${cli}    target tcp    ${{$config['pabTargetTcp']}}
    IT COMMON - Cli Number Should Equal    ${cli}    online interval    ${{$config['checkEcmOnlineInterval']}}
    IT COMMON - Cli Number Should Equal    ${cli}    retry interval    ${{$config['pabRetryInterval']}}
    IT COMMON - Cli Number Should Equal    ${cli}    RPD power threshold    ${{$config['rpdPwrdThreshold']}}
    IT COMMON - Cli Number Should Equal    ${cli}    outlier threshold    ${{$config['outlierThreshold']}}
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
