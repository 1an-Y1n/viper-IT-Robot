*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Check that the configuration is persisted in agc_data.json
Documentation    ASC | Config/Target Data save
...              Verify that the configuration changes are persisted to agc_data.json and restored after a restart (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-007-1]Persist ASC and AGC configuration across a service restart
    [Documentation]
    ...              Step 1. Save and set the ASC and AGC configuration values from the template
    ...              Step 2. Check both values in agc_data.json
    ...              Step 3. Restart sc-asc and verify the persisted values and startup log
    ...              Step 4. Restore the original values and verify them
    [Tags]    CLI    FILE    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_persist.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${old_mode}=    IT COMMON - Get Cli Field    ${before}    operationMode
    ${old}=    IT COMMON - Get Cli Field    ${before}    inputInterval
    ${old_power}=    IT COMMON - Get Cli Field    ${before}    inputPowerTransientThreshold
    ${agc_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${old_att}=    IT COMMON - Get Cli Field    ${agc_before}    pathloss change ATT Threshold
    ${old_eq}=    IT COMMON - Get Cli Field    ${agc_before}    pathloss change EQ Threshold
    ${old_notify}=    IT COMMON - Get Cli Field    ${agc_before}    Rfboard notify interval
    TRY
        IT ASC - Set And Verify Persisted Configuration    FreeRun    300    0.2    0.5    0.5    3600
        ${pid_before}=    IT COMMON - Run Dut Root Command And Return    systemctl --no-pager show -p MainPID --value sc-asc
        ${pid_before}=    Evaluate    $pid_before.strip()
        Should Match Regexp    ${pid_before}    ^[1-9][0-9]*$
        ${cursor}=    IT COMMON - Read Journal Cursor
        ${restart}=    IT COMMON - Run Dut Root Command And Return    systemctl restart sc-asc && echo SC_ASC_RESTART_OK    timeout=120
        Should Contain    ${restart}    SC_ASC_RESTART_OK
        Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active
        ${pid_after}=    IT COMMON - Run Dut Root Command And Return    systemctl --no-pager show -p MainPID --value sc-asc
        ${pid_after}=    Evaluate    $pid_after.strip()
        Should Match Regexp    ${pid_after}    ^[1-9][0-9]*$
        Should Not Be Equal    ${pid_after}    ${pid_before}    msg=sc-asc did not restart
        IT ASC - Live Configuration Should Equal    FreeRun    300    0.2    0.5    0.5    3600
        Wait Until Keyword Succeeds    120s    5s    IT ASC - Persisted Configuration Should Equal    FreeRun    300    0.2    0.5    0.5    3600
        ${errors}=    IT COMMON - Run Dut Root Command And Return    SYSTEMD_COLORS=0 journalctl --no-pager -u sc-asc --priority=err --after-cursor '${cursor}' -o cat
        Should Be Empty    ${errors.strip()}    msg=sc-asc logged errors during restart: ${errors}
    FINALLY
        SSH_IT_ROOT.Close
        SSH_IT_ROOT.Connect    ssh_setting=${SSH_DUT_IT}    level=ROOT    main_log_name=${case_name}-ssh_root.log
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Service Should Be Active
        IT ASC - Set And Verify Persisted Configuration    ${old_mode}    ${old}    ${old_power}    ${old_att}    ${old_eq}    ${old_notify}
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
