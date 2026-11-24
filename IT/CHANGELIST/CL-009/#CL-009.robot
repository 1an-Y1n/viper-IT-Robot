*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The 33368 byte MsgBody contract of amp-rfimgr-lib
Documentation    CHANGELIST | CUST_FACING
...              The MsgBody contract of amp-rfimgr-lib is restored, so the DS Tracker can be deployed and configured (DZ300-1920). The deploy of the binary needs the file server and is a step of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-009-1]Read the version of the image
    [Documentation]
    ...              Step 1. Read /sc_versions.txt
    ...              Step 2. The image has to be the release 00.04.006 or later
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-1_version.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt
    Log    ${out}
    Should Contain    ${out}    SW_VERSION=00.04.006
    Should Contain    ${out}    IMAGE_NAME=Viper_LE-CAMP-00.04.006

[CL-009-2]Check the state of the DS Tracker
    [Documentation]
    ...              Step 1. Check whether the DS Tracker service is there
    ...              Step 2. Look for the tracker process
    ...              Step 3. Read the version of the tracker from the syslog
    [Tags]    CLI    FILE
    VAR    ${sc_log}    ${case_name}-2_dstracker.log    scope=TEST
    ${service}=    IT COMMON - Run Dut Command And Return    systemctl is-active dstracker
    Log    ${service}
    ${process}=    IT COMMON - Run Dut Command And Return    ps aux | grep -i '[d]stracker'
    Log    ${process}
    ${version}=    IT COMMON - Run Dut Command And Return    grep -a 'Dstracker version' /dev/shm/syslog | tail -n 3
    Log    ${version}

[CL-009-3]Check the DPM configuration over gRPC
    [Documentation]
    ...              Step 1. Read the DPM configuration
    ...              Step 2. The answer has to report success
    [Tags]    GRPC
    VAR    ${sc_log}    ${case_name}-3_dpm.log    scope=TEST
    VAR    ${proto}    ds_periodic_maintanence.proto
    VAR    ${method}    gnoi.ds_periodic_maintanence.v1.DownstreamPeriodicMaintanence/GetDpmConfiguration
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}
    IT COMMON - Grpc Should Succeed    ${response}
    ${enabled}=    IT COMMON - Grpc Get Field    ${response}    enabled
    Log    ${enabled}

[CL-009-4]Look for the failure signature of the old MsgBody contract
    [Documentation]
    ...              Step 1. Count the Message too long lines of the syslog
    ...              Step 2. There has to be none
    ...              Step 3. Look for the CDF of the reset
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-4_signature.log    scope=TEST
    ${count}=    IT COMMON - Run Dut Command And Return    grep -acE 'Message too long|ampLib.c line' /dev/shm/syslog
    Log    ${count}
    ${number}=    Evaluate    int($count.strip())    modules=builtins
    Should Be Equal As Integers    ${number}    0
    ${cdf}=    IT COMMON - Run Dut Command And Return    ls -l /log/cdf
    Log    ${cdf}
    ${reset}=    IT COMMON - Run Dut Command And Return    grep -acE 'gencdf|palgencdf|Initiating AMP reset' /dev/shm/syslog
    Log    ${reset}
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
