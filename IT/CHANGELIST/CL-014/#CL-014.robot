*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The attenuator response reports the unclamped value
Documentation    CHANGELIST | ALIGNMENT
...              The AdjustAttenuatorResponse of sc-rfboard has to report the level that the hardware really applied and not the requested one (DZ300-1873).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${original}    ${EMPTY}
*** Test Cases ***
[CL-014-1]Turn the message recording on and record the state
    [Documentation]
    ...              Step 1. Create the flag file that turns the message recording on
    ...              Step 2. Read the attenuation of the SP DS port
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_record.log    scope=TEST
    ${flag}=    IT COMMON - Run Dut Command And Return    touch /mnt/sc_nonvol/sc_record_proto_msg
    ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2
    Log    ${before}
    Should Contain    ${before}    SP_DS_ATT
    ${original}=    Evaluate    [line for line in $before.splitlines() if 'SP_DS_ATT (' in line][0].split('config = ')[1].split(' dB')[0]    modules=builtins
    VAR    ${original}    ${original}    scope=SUITE

[CL-014-2]Send the out of range adjustment and read the applied value
    [Documentation]
    ...              Step 1. Send the relative adjustment that reaches the clamp
    ...              Step 2. Read the attenuation again, it has to be the minimum
    ...              Step 3. Look at the recorded response
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-2_clamp.log    scope=TEST
    ${request}=    IT COMMON - Run Dut Command And Return    cliwrapper_client -s /tmp/brcmhal.sock -t 1000 -d '/calibration/adjust_attenuator 1 -45.5'    timeout=60
    Log    ${request}
    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2
    Log    ${after}
    ${record}=    IT COMMON - Run Dut Command And Return    grep -a 'attenuation_db' /tmp/sc_rfboard_msg.log | tail -n 3
    Log    ${record}

[CL-014-3]Put the attenuation back
    [Documentation]
    ...              Step 1. Read the value that is in place now
    ...              Step 2. Put the value of the factory default back
    ...              Step 3. Read it again
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-3_restore.log    scope=TEST
    ${current}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2
    ${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_attenuation 2 ${original}
    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2
    Log    ${after}
    Should Contain    ${after}    SP_DS_ATT
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
