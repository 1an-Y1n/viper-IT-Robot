*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The gRPC ASC disable goes to Disable and not to Monitor
Documentation    CHANGELIST | ASC
...              The gRPC ASC disable has to switch the ASC to the Disable mode and not to the Monitor mode (DZ300-1988).
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
[CL-029-1]Disable the ASC over gRPC and check it
    [Documentation]
    ...              Step 1. Read the current configuration over gRPC
    ...              Step 2. SET the enable field to zero
    ...              Step 3. Read the configuration again, the enable has to be zero
    ...              Step 4. Read the configuration over sc_cli, it has to be Disable
    ...              Step 5. Check the configuration file
    ...              Step 6. Look at the syslog
    [Tags]    GRPC    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_disable.log    scope=TEST
    VAR    ${payload}    {"ascConfig": {"enable": 0}}
    ${before}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    IT COMMON - Grpc Should Succeed    ${before}
    ${set}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${payload}
    IT COMMON - Grpc Should Succeed    ${set}
    ${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    IT COMMON - Grpc Should Succeed    ${after}
    ${enable}=    IT COMMON - Grpc Number Should Equal    ${after}    ${{['ascConfig', 'enable']}}    0
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Log    ${cli}
    Should Contain    ${cli}    operationMode = Disable
    ${file}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/agc_data.json
    Should Contain    ${file}    operation_mode
    ${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'Operation mode\|Control loops stopping\|Enable AGC' /dev/shm/syslog | tail -n 10
    Log    ${syslog}

[CL-029-2]Enable the ASC over gRPC again
    [Documentation]
    ...              Step 1. SET the enable field to one
    ...              Step 2. Read the configuration over sc_cli, it has to be FreeRun
    [Tags]    GRPC    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_enable.log    scope=TEST
    VAR    ${payload}    {"ascConfig": {"enable": 1}}
    ${set}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${payload}
    IT COMMON - Grpc Should Succeed    ${set}
    ${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    IT COMMON - Grpc Number Should Equal    ${after}    ${{['ascConfig', 'enable']}}    1
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Log    ${cli}
    Should Contain    ${cli}    operationMode = FreeRun
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
