*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The NP DS out-of-range handler returns the input toward the AGC window
Documentation    ASC | Algorithm flowchart
...              Create and then restore an out-of-range north port input. Skipped until external signal control is implemented and validated.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-013-1]Handle and recover from an out-of-range input
    [Documentation]
    ...              Step 1. Save the original operation mode and log level
    ...              Step 2. Lower the north port input relative to calibration
    ...              Step 3. Check out-of-range adjustment and ON_HOLD
    ...              Step 4. Restore the input and check that TRACKING resumes
    ...              Step 5. Restore the operation mode and log level
    [Tags]    CLI    WRITE    MANUAL_BENCH    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-1_out_of_range.log    scope=TEST
    VAR    &{levels}    EMERG=0    ALERT=1    CRIT=2    ERR=3    WARN=4    NOTE=5    INFO=6    DEBUG=7
    ${snapshot}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    ${end_freq}=    IT COMMON - Get Cli Field    ${snapshot}    ds_end_frequency_hz
    Should Be True    int($end_freq.split()[0]) > 0    msg=Calibration snapshot is missing
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode
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
        ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
        ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
        IT COMMON - Cli Field Should Equal    ${config}    operationMode    FreeRun
        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        ${cursor}=    IT COMMON - Read Journal Cursor
        VAR    ${external_attempted}    ${TRUE}
        IT ASC EXTERNAL - Set North Port Input Delta    -6
        VAR    ${journal_cmd}    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'
        ${start}=    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    Start 1st OutRange handler process    timeout=600    interval=10
        ${boundary}=    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    SOC Input is adjusted to near AGC boundary    timeout=600    interval=10
        ${hold}=    IT COMMON - Wait For Dut Command Contains    sc_cli get_adu_status    name=ON_HOLD    timeout=120    interval=5
        IT ASC EXTERNAL - Restore North Port Signal
        VAR    ${external_attempted}    ${FALSE}
        ${tracking}=    IT COMMON - Wait For Dut Command Contains    sc_cli get_adu_status    name=TRACKING    timeout=600    interval=10
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
