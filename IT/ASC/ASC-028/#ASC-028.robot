*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Start and stop the control loops by hand
Documentation    ASC | Control & Status
...              Verify the manual start and stop control of the loops (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-028-1]Stop and start the control loops
    [Documentation]
    ...              Step 1. Stop the loops while NP DS is running
    ...              Step 2. Check all four loops stay stopped for an input interval
    ...              Step 3. Start the loops and verify NP DS runs again
    ...              Step 4. Disable ASC and verify stop and start are refused
    ...              Step 5. Restore the original mode and control state
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_control.log    scope=TEST
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode
    Should Be Equal    ${mode}    FreeRun    msg=This test requires FreeRun
    ${interval}=    IT COMMON - Get Cli Field    ${config}    inputInterval
    Should Be True    int($interval) > 0    msg=Invalid NP DS interval
    IT ASC - All FSMs Should Have State    true
    VAR    ${stop_attempted}    ${FALSE}
    TRY
        Wait Until Keyword Succeeds    600s    1s    IT ASC - NP DS Should Be Running
        ${cursor}=    IT COMMON - Read Journal Cursor
        VAR    ${stop_attempted}    ${TRUE}
        ${stop}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control stop
        Should Contain    ${stop}    set_agc_control success
        Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    false    ${TRUE}
        VAR    ${journal_cmd}    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'
        IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    Control loops stopping    timeout=30    interval=2
        ${stopped_at}=    Evaluate    time.monotonic()    modules=time
        WHILE    time.monotonic() - $stopped_at < int($interval) + 5
            IT ASC - All FSMs Should Have State    false    ${TRUE}
            Sleep    5s
        END
        ${start}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start
        Should Contain    ${start}    set_agc_control success
        VAR    ${stop_attempted}    ${FALSE}
        Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    true
        IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    Control loops starting    timeout=30    interval=2
        Wait Until Keyword Succeeds    600s    1s    IT ASC - NP DS Should Be Running
        IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0
        Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    false    ${TRUE}
        ${disabled_stop}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control stop
        Should Contain    ${disabled_stop}    set_agc_control failed
        ${disabled_start}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start
        Should Contain    ${disabled_start}    set_agc_control failed
    FINALLY
        Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}
        IF    $stop_attempted
            ${restore}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start
            Run Keyword And Continue On Failure    Should Contain    ${restore}    set_agc_control success
        END
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    true
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
