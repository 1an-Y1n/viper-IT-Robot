*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Run the ASC in Monitor mode and check that it does not write the RF
Documentation    ASC | OperationMode
...              Verify that Monitor mode runs the whole decision path without writing the RF (User Guide 10.4). Skipped until north port signal control is implemented.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-005-1]Run the ASC in Monitor mode
    [Documentation]
    ...              Step 1. Set the operation mode to Monitor
    ...              Step 2. Change the north port signal via the bench adapter
    ...              Step 3. Verify the NP DS decision and unchanged RF attenuation
    ...              Step 4. Restore the signal, log level and original operation mode
    [Tags]    CLI    WRITE    MANUAL_BENCH    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-1_monitor.log    scope=TEST
    VAR    @{fsms}    sp_ds    np_ds    clipping    np_us
    VAR    &{levels}    EMERG=0    ALERT=1    CRIT=2    ERR=3    WARN=4    NOTE=5    INFO=6    DEBUG=7
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode
    ${interval}=    IT COMMON - Get Cli Field    ${config}    inputInterval
    ${timeout}=    Evaluate    max(int($interval), 120) + 180
    ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli
    ${level_line}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc
    ${level}=    Evaluate    $level_line.split()[0]
    ${level_number}=    Get From Dictionary    ${levels}    ${level}
    VAR    ${external_attempted}    ${FALSE}
    TRY
        ${debug}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 7
        ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli
        ${debug_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc
        Should Start With    ${debug_level}    DEBUG
        ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 2
        ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
        IT COMMON - Cli Field Should Equal    ${config}    operationMode    Monitor
        ${sp_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status sp_ds
        ${np_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
        ${clipping}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status clipping
        ${np_us}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us
        FOR    ${fsm}    IN    @{fsms}
            ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled
            Should Be Equal    ${state}    true
        END
        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
        ${written_before}=    IT COMMON - Get Inline Values    ${before}    last_set
        ${configured_before}=    IT COMMON - Get Inline Values    ${before}    config
        Should Not Be Empty    ${written_before}
        Should Not Be Empty    ${configured_before}
        ${cursor}=    IT COMMON - Read Journal Cursor
        VAR    ${external_attempted}    ${TRUE}
        IT ASC EXTERNAL - Set North Port Input Delta    -3
        Wait Until Keyword Succeeds    ${timeout}s    2s    IT ASC - NP DS Should Be Running
        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        VAR    ${journal_cmd}    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'
        ${journal}=    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    [NpDs][Measure] ASC is in monitor mode. Will not adjust RF components    timeout=60    interval=5
        ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
        ${written_after}=    IT COMMON - Get Inline Values    ${after}    last_set
        ${configured_after}=    IT COMMON - Get Inline Values    ${after}    config
        Should Be Equal    ${written_after}    ${written_before}
        Should Be Equal    ${configured_after}    ${configured_before}
    FINALLY
        IF    $external_attempted
            Run Keyword And Continue On Failure    IT ASC EXTERNAL - Restore North Port Signal
        END
        Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}
        ${restore_log}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l ${level_number}
        ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli
        ${restored_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc
        Should Start With    ${restored_level}    ${level}
    END
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
    # the suite has nothing to clean up
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
