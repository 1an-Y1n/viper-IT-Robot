*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The ADU status follows the operation mode
Documentation    ASC | Control & Status
...              Verify that the ADU status reflects the operation mode and the guardrail latches (User Guide 10.4). Skipped until external north port signal control is implemented and validated.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-029-1]Check ADU status across operation modes and an out-of-range event
    [Documentation]
    ...              Step 1. Check OFF in Disable and Monitor
    ...              Step 2. Check TRACKING in FreeRun
    ...              Step 3. Trigger an out-of-range event and check ON_HOLD
    ...              Step 4. Restore the signal and check TRACKING resumes
    ...              Step 5. Restore the original mode
    [Tags]    CLI    WRITE    MANUAL_BENCH    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-1_adu.log    scope=TEST
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode
    ${snapshot}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    ${end_freq}=    IT COMMON - Get Cli Field    ${snapshot}    ds_end_frequency_hz
    Should Be True    int($end_freq.split()[0]) > 0    msg=Calibration snapshot is missing
    VAR    ${external_attempted}    ${FALSE}
    TRY
        IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0
        ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
        IT COMMON - Cli Field Should Equal    ${config}    operationMode    Disable
        Wait Until Keyword Succeeds    120s    5s    IT ASC - ADU State Should Be    OFF
        IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 2
        ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
        IT COMMON - Cli Field Should Equal    ${config}    operationMode    Monitor
        Wait Until Keyword Succeeds    120s    5s    IT ASC - ADU State Should Be    OFF
        IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
        ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
        IT COMMON - Cli Field Should Equal    ${config}    operationMode    FreeRun
        Wait Until Keyword Succeeds    120s    5s    IT ASC - ADU State Should Be    TRACKING
        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        VAR    ${external_attempted}    ${TRUE}
        IT ASC EXTERNAL - Set North Port Input Delta    -6
        Wait Until Keyword Succeeds    600s    5s    IT ASC - ADU State Should Be    ON_HOLD
        IT ASC EXTERNAL - Restore North Port Signal
        VAR    ${external_attempted}    ${FALSE}
        Wait Until Keyword Succeeds    600s    5s    IT ASC - ADU State Should Be    TRACKING
    FINALLY
        IF    $external_attempted
            Run Keyword And Continue On Failure    IT ASC EXTERNAL - Restore North Port Signal
        END
        Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}
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
