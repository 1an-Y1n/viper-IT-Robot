*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: PAB configuration set and get, FreeRun control, and the eCM check
Documentation    PAB | Sercomm CLI / PAB
...              Preset a PAB configuration and verify. Trigger PAB FreeRun and
...              verify the current status (User Guide 6.1, 6.2).
Resource    ../../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# The values the User Guide 6.1 recommends: rx_adc_lna_mode = 2 (FREE_RUNNING)
# and target TCP = 36.00 dBmV.
${pab_lna_mode}    2
${pab_lna_gain}    2.74
${pab_target_tcp}    36.00
${pab_online_interval}    60
${pab_retry_interval}    60
${pab_rpd_threshold}    -21.78
${pab_outlier_threshold}    6.00

*** Test Cases ***
[PAB-001-1]Preset the PAB configuration
    [Documentation]
    ...              | > Step 1. GET and SET PAB CONFIG
    ...              | > Step 2. GET the configuration back and check it took
    [Tags]    PAB    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_sc_cli.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config    log_name=${sc_log}
    Log    ${before}
    ${set_cmd}=    Catenate
    ...    SEPARATOR=${SPACE}
    ...    sc_cli set_pab_config
    ...    ${pab_lna_mode}
    ...    ${pab_lna_gain}
    ...    ${pab_target_tcp}
    ...    ${pab_online_interval}
    ...    ${pab_retry_interval}
    ...    ${pab_rpd_threshold}
    ...    ${pab_outlier_threshold}
    ${set_out}=    IT COMMON - Run Dut Command And Return    ${set_cmd}    log_name=${sc_log}
    Log    ${set_out}
    Should Contain    ${set_out}    Success
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config    log_name=${sc_log}
    Log    ${after}
    # The read back has to carry the values that were just written, otherwise
    # the DUT accepted the command and ignored it.
    ${mode}=    IT COMMON - Cli Field Should Equal    ${after}    rx adc lna mode    ${pab_lna_mode} (FREE_RUNNING)
    ${gain}=    IT COMMON - Cli Field Should Equal    ${after}    rx adc lna gain    ${pab_lna_gain} dBmV
    ${tcp}=    IT COMMON - Cli Field Should Equal    ${after}    target tcp    ${pab_target_tcp} dBmV
    ${online}=    IT COMMON - Cli Field Should Equal    ${after}    online interval    ${pab_online_interval} sec
    ${retry}=    IT COMMON - Cli Field Should Equal    ${after}    retry interval    ${pab_retry_interval} sec
    ${rpd}=    IT COMMON - Cli Field Should Equal    ${after}    RPD power threshold    ${pab_rpd_threshold} dBmV
    ${outlier}=    IT COMMON - Cli Field Should Equal    ${after}    outlier threshold    ${pab_outlier_threshold}

[PAB-001-2]Trigger PAB FreeRun and check the status
    [Documentation]
    ...              | > Step 1. Stop PAB, then start it again in FreeRun
    ...              | > Step 2. Wait until Running Status = DONE and Current Stage = IDLE
    ...              | > Step 3. Verify the eCM is operational
    [Tags]    PAB    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_sc_cli.log    scope=TEST
    ${stop}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control stop    log_name=${sc_log}
    Log    ${stop}
    Should Contain    ${stop}    Success
    ${run}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control free_run    log_name=${sc_log}
    Log    ${run}
    Should Contain    ${run}    Success
    # A round takes a while, and right after free_run the status still reads
    # "Running Status : DONE" while the stage is STAGE1. So the wait is on the
    # whole terminal state, not on the running status alone.
    ${fields}=    Create List
    ...    Running Mode=FREERUN
    ...    Completed=Yes
    ...    Current Stage=IDLE
    ${status}=    IT COMMON - Wait For Dut Cli Fields
    ...    sc_cli get_pab_status
    ...    ${fields}
    ...    timeout=300    interval=10
    Log    ${status}
    ${enabled}=    IT COMMON - Cli Field Should Equal    ${status}    Enabled    Yes
    ${completed}=    IT COMMON - Cli Field Should Equal    ${status}    Completed    Yes
    ${ecm}=    IT COMMON - Cli Field Should Equal    ${status}    eCM online    Yes
    ${mode}=    IT COMMON - Cli Field Should Equal    ${status}    Running Mode    FREERUN
    ${running}=    IT COMMON - Cli Field Should Equal    ${status}    Running Status    DONE
    ${stage}=    IT COMMON - Cli Field Should Equal    ${status}    Current Stage    IDLE

[PAB-001-3]Verify the eCM is operational
    [Documentation]
    ...              | > Step 1. Read the eCM status from the linux shell
    ...              | > Step 2. The eCM has to be Operational
    [Tags]    PAB    CLI
    VAR    ${sc_log}    ${case_name}-3_sc_cli.log    scope=TEST
    # The eCM goes through a range start after it comes up, so the status is
    # waited for instead of being read once.
    ${out}=    IT COMMON - Wait For Dut Command Contains
    ...    sc_amphal_cli get_ecm_status
    ...    eCM status = Operational
    ...    timeout=180    interval=10
    Log    ${out}
    Should Contain    ${out}    eCM status = Operational

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
