*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The completion status and the MSC completion flag do not diverge
Documentation    CHANGELIST | PAB
...              The completion status of the PAB and the MSC completion flag must not diverge after a PAB run (DZ300-1979).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-026-1]Check that the fix is in the image
    [Documentation]
    ...              Step 1. Look for the two error messages of the old behaviour in the binary
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-1_fix.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    strings /usr/bin/sc_alignment | grep -a 'PAB snapshot persistence failed'
    Log    ${out}
    ${flag}=    IT COMMON - Run Dut Command And Return    strings /usr/bin/sc_alignment | grep -a 'Failed to set pab_completed_config_flag'
    Log    ${flag}

[CL-026-2]Run the PAB again and check the completion
    [Documentation]
    ...              Step 1. Read the PAB status
    ...              Step 2. Start the PAB in FreeRun mode
    ...              Step 3. Wait until the round is over
    ...              Step 4. Look for the stage seven lines of the syslog
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-2_rerun.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    Log    ${before}
    ${run}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control free_run
    Should Contain    ${run}    Success
    ${fields}=    Create List    Running Mode=FREERUN    Completed=Yes    Current Stage=IDLE
    ${status}=    IT COMMON - Wait For Dut Cli Fields    sc_cli get_pab_status    ${fields}    timeout=300    interval=10
    Log    ${status}
    ${syslog}=    IT COMMON - Run Dut Command And Return    grep -a '\[ScPabStage7\]' /dev/shm/syslog | tail -n 10
    Log    ${syslog}

[CL-026-3]Check the state after the run
    [Documentation]
    ...              Step 1. Read the MSC controller
    ...              Step 2. Read the PAB status
    ...              Step 3. The completion flag and the status must not diverge
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-3_after.log    scope=TEST
    ${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    Log    ${controller}
    Log    ${status}
    ${completed}=    IT COMMON - Get Cli Field    ${status}    Completed
    Should Be Equal    ${completed}    Yes
    ${mode}=    IT COMMON - Get Cli Field    ${status}    Running Mode
    Should Be Equal    ${mode}    FREERUN
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
