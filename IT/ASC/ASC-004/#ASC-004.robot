*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Run the ASC in FreeRun mode and check that it adjusts the RF
Documentation    ASC | OperationMode
...              Verify that FreeRun mode runs the control loops and adjusts the RF (User Guide 10.4). Skipped until north port signal control is implemented.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-004-1]Run the ASC in FreeRun mode
    [Documentation]
    ...              Step 1. Check that the calibration snapshot holds data
    ...              Step 2. Set FreeRun and verify the loops and ADU
    ...              Step 3. Change the north port signal via the bench adapter
    ...              Step 4. Wait for NP DS and check that RF attenuation changed
    ...              Step 5. Restore the signal and original operation mode
    [Tags]    CLI    WRITE    MANUAL_BENCH    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-1_free_run.log    scope=TEST
    VAR    @{fsms}    sp_ds    np_ds    clipping    np_us
    ${snapshot}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    ${end_freq}=    IT COMMON - Get Cli Field    ${snapshot}    ds_end_frequency_hz
    Should Be True    int($end_freq.split()[0]) > 0    msg=Calibration snapshot is missing
    ${pab}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    ${enabled}=    IT COMMON - Get Cli Field    ${pab}    Enabled
    ${completed}=    IT COMMON - Get Cli Field    ${pab}    Completed
    Should Be True    $enabled == 'No' or $completed == 'Yes'    msg=PAB is not complete
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode
    ${interval}=    IT COMMON - Get Cli Field    ${config}    inputInterval
    ${timeout}=    Evaluate    max(int($interval), 120) + 180
    VAR    ${external_attempted}    ${FALSE}
    TRY
        ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
        ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
        IT COMMON - Cli Field Should Equal    ${config}    operationMode    FreeRun
        ${sp_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status sp_ds
        ${np_ds}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
        ${clipping}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status clipping
        ${np_us}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_us
        FOR    ${fsm}    IN    @{fsms}
            ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled
            Should Be Equal    ${state}    true
        END
        ${adu}=    IT COMMON - Run Dut Command And Return    sc_cli get_adu_status
        ${adu_name}=    IT COMMON - Get Inline Field    ${adu}    name
        Should Be Equal    ${adu_name}    TRACKING
        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
        ${written_before}=    IT COMMON - Get Inline Values    ${before}    last_set
        Should Not Be Empty    ${written_before}
        VAR    ${external_attempted}    ${TRUE}
        IT ASC EXTERNAL - Set North Port Input Delta    -3
        Wait Until Keyword Succeeds    ${timeout}s    2s    IT ASC - NP DS Should Be Running
        Wait Until Keyword Succeeds    180s    5s    IT ASC - NP DS Should Be Idle
        ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
        ${written_after}=    IT COMMON - Get Inline Values    ${after}    last_set
        Should Not Be Equal    ${written_after}    ${written_before}    msg=FreeRun did not change RF attenuation
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
