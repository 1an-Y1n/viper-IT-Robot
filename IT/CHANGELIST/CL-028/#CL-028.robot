*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The eAMP talks to the eCM over SNMP instead of the UDP RPC
Documentation    CHANGELIST | CUST_FACING
...              The UDP RPC between the eAMP and the eCM is replaced by SNMP (CAMP-2414).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-028-1]Check the version and the reachability of the eCM
    [Documentation]
    ...              Step 1. Read the version of the image
    ...              Step 2. Ping the management address of the eCM
    [Tags]    CLI    FILE
    VAR    ${sc_log}    ${case_name}-1_baseline.log    scope=TEST
    ${version}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt
    Should Contain    ${version}    SW_VERSION=00.04.006
    ${ping}=    IT COMMON - Run Dut Command And Return    ping -c 2 -W 3 172.31.255.45    timeout=30
    Log    ${ping}

[CL-028-2]Read the upstream diagnosis
    [Documentation]
    ...              Step 1. Run sc_cli get_upstream_diagnosis
    ...              Step 2. The answer has to hold the channels with their frequency and their power
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_diagnosis.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    sc_cli get_upstream_diagnosis    timeout=60
    Log    ${out}
    Should Contain    ${out}    Upstream Diagnosis:
    Should Contain    ${out}    Number of channels:
    Should Contain    ${out}    frequency_hz=
    Should Contain    ${out}    power_dbmv=

[CL-028-3]Check that the SNMP client of the eAMP is used
    [Documentation]
    ...              Step 1. Look at the sc_amphal lines of the syslog
    ...              Step 2. They have to show the SNMP client and the upstream diagnosis
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-3_syslog.log    scope=TEST
    ${syslog}=    IT COMMON - Run Dut Command And Return    grep -a sc_amphal /dev/shm/syslog | tail -n 20
    Log    ${syslog}
    Should Contain    ${syslog}    ScEcmSnmpClient init done
    Should Contain    ${syslog}    GetUpstreamDiagnosisRaw
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
