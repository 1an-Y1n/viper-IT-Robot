*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Every GEN2 device type is mapped in the running configuration
Documentation    CHANGELIST | CUST_FACING
...              Every GEN2 device type is mapped in the answer of the RunningConfiguration service (CAMP-2536).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    running_configuration.proto
${method}    gnoi.running_configuration.v1.RunningConfiguration/GetConfiguration
*** Test Cases ***
[CL-021-1]Read the running configuration over gRPC
    [Documentation]
    ...              Step 1. Call GetConfiguration
    ...              Step 2. The answer has to carry a success block and no failure block
    ...              Step 3. The three attenuation lists have to hold one MAIN_PORT entry
    [Tags]    GRPC
    VAR    ${sc_log}    ${case_name}-1_configuration.log    scope=TEST
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${EMPTY}    timeout=60
    IT COMMON - Grpc Should Succeed    ${response}
    IT COMMON - Grpc Should Not Have Field    ${response}    failure
    ${north}=    IT COMMON - Grpc Get Field    ${response}    northAfeAttenuations
    ${ds_output}=    IT COMMON - Grpc Get Field    ${response}    dsOutputAttenuations
    ${legacy}=    IT COMMON - Grpc Get Field    ${response}    legacyUsInputAttenuations
    ${north_count}=    Evaluate    len($north)    modules=builtins
    Should Be Equal As Integers    ${north_count}    1
    ${ds_count}=    Evaluate    len($ds_output)    modules=builtins
    Should Be Equal As Integers    ${ds_count}    1
    ${legacy_count}=    Evaluate    len($legacy)    modules=builtins
    Should Be Equal As Integers    ${legacy_count}    1

[CL-021-2]Look at the syslog of the call
    [Documentation]
    ...              Step 1. Look for the reads of the downstream and the legacy upstream attenuation
    ...              Step 2. There must not be an invalid port number
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-2_syslog.log    scope=TEST
    ${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'palGetDsOutputPortAtten\|palGetLegacyUsInputAtten\|Invalid port number' /dev/shm/syslog | tail -n 10
    Log    ${syslog}
    Should Not Contain    ${syslog}    Invalid port number: 1
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
