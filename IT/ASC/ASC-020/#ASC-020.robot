*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The telemetry is persisted at the persist interval
Documentation    ASC | Telemetry
...              Verify that the telemetry is persisted periodically and once more at shutdown (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-020-1]Verify periodic and shutdown telemetry persistence
    [Documentation]
    ...              Step 1. Save the original interval, set it to 60 s and restart sc-asc
    ...              Step 2. Verify a periodic write and a write during service restart
    ...              Step 3. Restore the original interval
    [Tags]    CLI    FILE    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_persist.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${old}=    IT COMMON - Get Cli Field    ${before}    Telemetry persist interval
    VAR    ${path}    /mnt/sc_nonvol/agc_telemetry_data.json
    TRY
        ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 15 60
        Should Contain    ${set}    set_agc_config...success
        Wait Until Keyword Succeeds    120s    5s    IT ASC - Telemetry Interval Should Equal    60
        ${restart}=    IT COMMON - Run Dut Root Command And Return    systemctl restart sc-asc && echo SC_ASC_RESTART_OK    timeout=120
        Should Contain    ${restart}    SC_ASC_RESTART_OK
        Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active
        Wait Until Keyword Succeeds    120s    5s    IT ASC - Telemetry Interval Should Equal    60
        ${initial}=    IT COMMON - Run Dut Root Command And Return    stat -c %Y ${path}
        Should Match Regexp    ${initial.strip()}    ^[0-9]+$
        ${cursor}=    IT COMMON - Read Journal Cursor
        VAR    ${journal_cmd}    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'
        IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    Scheduled telemetry persistence completed    timeout=150    interval=5
        ${periodic}=    IT COMMON - Run Dut Root Command And Return    stat -c %Y ${path}
        Should Be True    int($periodic.strip()) > int($initial.strip())    msg=Telemetry file was not updated periodically
        Sleep    2s
        ${cursor}=    IT COMMON - Read Journal Cursor
        ${restart}=    IT COMMON - Run Dut Root Command And Return    systemctl restart sc-asc && echo SC_ASC_RESTART_OK    timeout=120
        Should Contain    ${restart}    SC_ASC_RESTART_OK
        Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active
        ${shutdown}=    IT COMMON - Run Dut Root Command And Return    stat -c %Y ${path}
        Should Be True    int($shutdown.strip()) > int($periodic.strip())    msg=Telemetry file was not written at shutdown
        ${journal}=    IT COMMON - Run Dut Root Command And Return    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'
        Should Contain    ${journal}    Saving telemetry data during shutdown
    FINALLY
        SSH_IT_ROOT.Close
        SSH_IT_ROOT.Connect    ssh_setting=${SSH_DUT_IT}    level=ROOT    main_log_name=${case_name}-ssh_root.log
        ${active}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Root Command And Return    systemctl is-active sc-asc
        IF    $active is not None and $active.strip() == 'inactive'
            Run Keyword And Continue On Failure    IT COMMON - Run Dut Root Command And Return    systemctl start sc-asc    timeout=120
        END
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active
        ${restored}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 15 ${old}
        Run Keyword And Continue On Failure    Should Contain    ${restored}    set_agc_config...success
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Telemetry Interval Should Equal    ${old}
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
