*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set the PAB configuration over gRPC and check that the values took
Documentation    PAB | GRPC Configuration, Status & Control
...              Set the parameters of the PAB process with grpcurl, check that the SET was successful and that the GET returns the new values (User Guide 12.1.4.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    pab_config.proto
${method}    gnoi.pab_config.v1.PabConfig/SetPabConfiguration
${get_method}    gnoi.pab_config.v1.PabConfig/GetPabConfiguration
${original}    ${EMPTY}
${restore_payload}    ${EMPTY}
*** Test Cases ***
[PAB-012-1]SET the PAB configuration over gRPC
    [Documentation]
    ...              Step 1. Read the configuration that is in place now
    ...              Step 2. SET the new configuration
    ...              Step 3. Check that the SET was successful
    [Tags]    GRPC    WRITE
    VAR    ${sc_log}    ${case_name}-1_grpc.log    scope=TEST
    VAR    ${payload}    {"pabConfig": {"rxAdcLnaGain": 2.74, "pabTargetTcp": 36.0, "checkEcmOnlineInterval": 60, "pabRetryInterval": 60, "rpdPwrdThreshold": -27.78, "outlierThreshold": 6.0}}
    ${before}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    ${original}=    IT COMMON - Grpc Get Field    ${before}    pabConfig
    VAR    ${original}    ${original}    scope=SUITE
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}
    IT COMMON - Grpc Should Succeed    ${response}
    ${restore}=    Evaluate    json.dumps({'pabConfig': $original})    modules=json
    VAR    ${restore_payload}    ${restore}    scope=SUITE

[PAB-012-2]GET the configuration back and check the new values
    [Documentation]
    ...              Step 1. GET the PAB configuration
    ...              Step 2. Compare the values with the ones that were SET
    ...              Step 3. Cross check with sc_cli get_pab_config
    [Tags]    GRPC    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_grpc_cli.log    scope=TEST
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    IT COMMON - Grpc Should Succeed    ${response}
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'rxAdcLnaGain']}}    2.74
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'pabTargetTcp']}}    36.00
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'checkEcmOnlineInterval']}}    60
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'pabRetryInterval']}}    60
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'rpdPwrdThreshold']}}    -27.78
    IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'outlierThreshold']}}    6.00
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config
    IT COMMON - Cli Number Should Equal    ${cli}    rx adc lna gain    2.74
    IT COMMON - Cli Number Should Equal    ${cli}    target tcp    36.00
    IT COMMON - Cli Number Should Equal    ${cli}    RPD power threshold    -27.78
    IT COMMON - Cli Number Should Equal    ${cli}    outlier threshold    6.00
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
    # Put the PAB configuration back, so the DUT is left as it was.
    IT COMMON - Restore Grpc Configuration
    ...    ${proto}    ${method}    ${get_method}    ${restore_payload}
    ...    ${{['pabConfig', 'rpdPwrdThreshold']}}
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
