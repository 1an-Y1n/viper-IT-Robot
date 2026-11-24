*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set the ASC configuration and read it back
Documentation    ASC | CLI Configuration
...              Set the template ASC configuration, verify the NP DS timer and pilot trigger, reboot and verify persistence. Restore the original values.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-001-1]Set the ASC configuration and read it back
    [Documentation]
    ...              Step 1. Check that the NP DS loop is enabled and save the configuration
    ...              Step 2. Set the template values and check their readback
    ...              Step 3. Check that the pilot change triggers NP DS and the 300 s timer runs
    ...              Step 4. Reboot and check that all four values persisted
    ...              Step 5. Restore and verify the original configuration and log level
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_asc_config.log    scope=TEST
    VAR    &{levels}    EMERG=0    ALERT=1    CRIT=2    ERR=3    WARN=4    NOTE=5    INFO=6    DEBUG=7
    Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${mode}=    IT COMMON - Get Cli Field    ${before}    operationMode
    ${interval}=    IT COMMON - Get Cli Field    ${before}    inputInterval
    ${threshold}=    IT COMMON - Get Cli Field    ${before}    inputPowerTransientThreshold
    ${pilot}=    IT COMMON - Get Cli Field    ${before}    thirdPilotFrequency
    ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli
    ${level_line}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc
    ${level}=    Evaluate    $level_line.split()[0]
    ${level_number}=    Get From Dictionary    ${levels}    ${level}
    TRY
        ${debug}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 7
        ${logger}=    IT COMMON - Run Dut Command And Return    sc_log_cli
        ${debug_level}=    IT COMMON - Get Text After Label    ${logger}    Z_ScAgc
        Should Start With    ${debug_level}    DEBUG
        ${set_mode}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
        ${set_threshold}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputPowerTransientThreshold 0.0
        IF    int($pilot) == 1095000000
            ${set_alternate}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config thirdPilotFrequency 903000000
            Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        END
        ${cursor}=    IT COMMON - Read Journal Cursor
        ${set_pilot}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config thirdPilotFrequency 1095000000
        Wait Until Keyword Succeeds    180s    2s    IT ASC - NP DS Should Be Running
        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        ${set_short}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 120
        ${set_interval}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 300
        ${timer_start}=    Evaluate    time.monotonic()    modules=time
        ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
        IT COMMON - Cli Field Should Equal    ${config}    operationMode    FreeRun
        IT COMMON - Cli Number Should Equal    ${config}    inputInterval    300
        IT COMMON - Cli Number Should Equal    ${config}    inputPowerTransientThreshold    0.0
        IT COMMON - Cli Number Should Equal    ${config}    thirdPilotFrequency    1095000000
        ${journal_cmd}=    Set Variable    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc -o cat --after-cursor '${cursor}'
        ${journal}=    IT COMMON - Wait For Dut Command Contains    ${journal_cmd}    NP DS loop timer armed: 300s    timeout=60    interval=5
        Should Contain    ${journal}    Pilot 3 changed to 1095000000 Hz
        WHILE    time.monotonic() - $timer_start < 270
            IT ASC - NP DS Should Be Idle
            Sleep    5s
        END
        Wait Until Keyword Succeeds    90s    2s    IT ASC - NP DS Should Be Running
        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        ${boot_id}=    IT ASC - Get DUT Boot ID
        Run Keyword And Ignore Error    IT COMMON - Run Fdx Command And Return    reset
        Wait Until Keyword Succeeds    900s    10s    IT ASC - Confirm DUT Reboot    ${boot_id}
        ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
        IT COMMON - Cli Field Should Equal    ${after}    operationMode    FreeRun
        IT COMMON - Cli Number Should Equal    ${after}    inputInterval    300
        IT COMMON - Cli Number Should Equal    ${after}    inputPowerTransientThreshold    0.0
        IT COMMON - Cli Number Should Equal    ${after}    thirdPilotFrequency    1095000000
    FINALLY
        Wait Until Keyword Succeeds    900s    10s    IT COMMON - Wait For Dut To Come Back    timeout=20    interval=5
        Run Keyword And Continue On Failure    IT ASC - Restore ASC Configuration    ${mode}    ${interval}    ${threshold}    ${pilot}
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
