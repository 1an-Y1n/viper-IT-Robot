*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Stage F of the FDX enablement can be run again
Documentation    CHANGELIST | ALIGNMENT
...              The Stage F of the FDX enablement has to be re-runnable after it completed once (CAMP-2439).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-016-1]Read the version of the image
    [Documentation]
    ...              Step 1. Read /sc_versions.txt
    ...              Step 2. The image has to be the release 00.04.006 or later
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-1_version.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt
    Log    ${out}
    Should Contain    ${out}    SW_VERSION=00.04.006
    Should Contain    ${out}    IMAGE_NAME=Viper_LE-CAMP-00.04.006

[CL-016-2]Check that the gRPC method is there
    [Documentation]
    ...              Step 1. List the methods of the FdxEnablement service
    ...              Step 2. NonRootConfigureBackoff has to be listed
    [Tags]    GRPC
    VAR    ${sc_log}    ${case_name}-2_method.log    scope=TEST
    VAR    ${cmd}    grpcurl -plaintext -import-path /etc/amp/proto -proto fdx_enablement.proto 127.0.0.1:9338 list gnoi.fdx_enablement.v1.FdxEnablement
    ${out}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    timeout=30
    Log    ${out}
    Should Contain    ${out}    NonRootConfigureBackoff

[CL-016-3]Call the method twice and check that both calls succeed
    [Documentation]
    ...              Step 1. Call NonRootConfigureBackoff
    ...              Step 2. Call it a second time, it has to succeed as well
    ...              Step 3. Look at the syslog of the two calls
    [Tags]    GRPC    WRITE
    VAR    ${sc_log}    ${case_name}-3_call.log    scope=TEST
    VAR    ${cmd}    grpcurl -plaintext -import-path /etc/amp/proto -proto fdx_enablement.proto -d '{}' 127.0.0.1:9338 gnoi.fdx_enablement.v1.FdxEnablement.NonRootConfigureBackoff
    ${first}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    timeout=60
    Log    ${first}
    Should Contain    ${first}    SUCCESS
    ${second}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    timeout=60
    Log    ${second}
    Should Contain    ${second}    SUCCESS
    ${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'NonRootConfigureBackoff' /dev/shm/syslog | tail -n 10
    Log    ${syslog}
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
