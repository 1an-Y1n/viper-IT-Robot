*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The run-time log of sc-asc is aligned with sc-agc
Documentation    CHANGELIST | ASC
...              The run-time log of the sc-asc daemon is aligned with the one of sc-agc (DZ300-1588).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-006-1]Read the version and the state of the daemon
    [Documentation]
    ...              Step 1. Read /sc_versions.txt
    ...              Step 2. The image has to be the release 00.04.006 or later
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-1_baseline.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt
    Log    ${out}
    Should Contain    ${out}    SW_VERSION=00.04.006
    Should Contain    ${out}    IMAGE_NAME=Viper_LE-CAMP-00.04.006

[CL-006-2]Read the service and the configuration of the ASC
    [Documentation]
    ...              Step 1. Check that the sc-asc service is running
    ...              Step 2. Read the ASC and the AGC configuration
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_service.log    scope=TEST
    ${service}=    IT COMMON - Run Dut Command And Return    systemctl status sc-asc --no-pager
    Log    ${service}
    Should Contain    ${service}    Active: active (running)
    ${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    Log    ${asc}
    Log    ${agc}
    Should Contain    ${asc}    operationMode
    Should Contain    ${asc}    inputInterval
    Should Contain    ${agc}    Legacy enable
    Should Contain    ${agc}    Fdx enable

[CL-006-3]Check the default configuration file
    [Documentation]
    ...              Step 1. Check that agc_data.json is there
    ...              Step 2. Read its version
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-3_default_config.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol/agc_data.json
    Log    ${out}
    Should Not Contain    ${out}    No such file
    ${version}=    IT COMMON - Run Dut Command And Return    grep -a -m1 version /mnt/sc_nonvol/agc_data.json
    Log    ${version}
    Should Contain    ${version}    version

[CL-006-4]Set the input interval and read it back
    [Documentation]
    ...              Step 1. Set the input interval to 90 s
    ...              Step 2. Read the configuration back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-4_persistence.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${old}=    IT COMMON - Get Cli Field    ${before}    inputInterval
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 90
    Log    ${set}
    Should Contain    ${set}    success
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    IT COMMON - Cli Number Should Equal    ${after}    inputInterval    90
    ${back}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval ${old}
    ${restored}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    IT COMMON - Cli Number Should Equal    ${restored}    inputInterval    ${old}

[CL-006-5]Check the validation of the tuning IDs of the AGC
    [Documentation]
    ...              Step 1. Set the three invalid tuning IDs, they have to be refused
    ...              Step 2. Set the two valid tuning IDs, they have to be accepted
    ...              Step 3. Put the AGC configuration back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-5_tuning_ids.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${old_legacy}=    IT COMMON - Get Cli Field    ${before}    Legacy enable
    ${old_track}=    IT COMMON - Get Cli Field    ${before}    Track eCM power enable
    ${invalid0}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 0 1
    ${invalid19}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 19 1
    ${invalid25}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 25 1
    Log    ${invalid0}
    Log    ${invalid19}
    Log    ${invalid25}
    ${valid3}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 3 1
    Log    ${valid3}
    ${valid8}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 8 1
    Log    ${valid8}
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    Log    ${after}
    Should Contain    ${after}    Legacy enable: true
    Should Contain    ${after}    Track eCM power enable: true

[CL-006-6]Check the controller handover and the NP DS loop
    [Documentation]
    ...              Step 1. Read the MSC controller
    ...              Step 2. Read the state of the NP DS machine
    ...              Step 3. Look for the transient entries of the loop in the syslog
    [Tags]    CLI    FILE
    VAR    ${sc_log}    ${case_name}-6_controller.log    scope=TEST
    ${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller
    Log    ${controller}
    Should Contain    ${controller}    MSC controller:
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    Log    ${status}
    ${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'TRANSIENT' /dev/shm/syslog | tail -n 5
    Log    ${syslog}

[CL-006-7]Check that there is no CRIT in the syslog
    [Documentation]
    ...              Step 1. Count the CRIT lines of the syslog
    ...              Step 2. There has to be none
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-7_crit.log    scope=TEST
    ${count}=    IT COMMON - Run Dut Command And Return    grep -ac 'CRIT' /dev/shm/syslog
    Log    ${count}
    ${number}=    Evaluate    int($count.strip())    modules=builtins
    Should Be Equal As Integers    ${number}    0
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
