*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The FSM status query reports the state of the loops
Documentation    ASC | Control & Status
...              Verify that get_asc_fsm_status reports the loop state (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-030-1]Check FSM status while enabled, running and disabled
    [Documentation]
    ...              Step 1. Validate all four FSM status responses
    ...              Step 2. Observe an in-flight NP DS round and its completed count
    ...              Step 3. Disable ASC and verify all FSMs are disabled
    ...              Step 4. Restore the original mode
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_fsm.log    scope=TEST
    VAR    &{fsms}    np_ds=NpDs    sp_ds=SpDs    np_us=NpUs    clipping=Clipping
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${mode}=    IT COMMON - Get Cli Field    ${config}    operationMode
    Should Be Equal    ${mode}    FreeRun    msg=This test requires FreeRun
    FOR    ${fsm}    ${name}    IN    &{fsms}
        IT ASC - FSM Status Should Be Valid    ${fsm}    ${name}    true
    END
    Wait Until Keyword Succeeds    180s    2s    IT ASC - NP DS Should Be Idle
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    ${before_count}=    IT COMMON - Get Cli Field    ${before}    loop_count
    TRY
        ${inflight}=    Wait Until Keyword Succeeds    600s    1s    IT ASC - NP DS Should Be Running
        ${stage}=    IT COMMON - Get Cli Field    ${inflight}    current_stage
        Should Not Be Equal    ${stage}    Idle
        Wait Until Keyword Succeeds    180s    2s    IT ASC - NP DS Should Be Idle
        ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
        ${after_count}=    IT COMMON - Get Cli Field    ${after}    loop_count
        Run Keyword And Continue On Failure    Should Be True    int($after_count) > int($before_count)    msg=NP DS loop_count did not accumulate after a completed round (${before_count} -> ${after_count})
        IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0
        Wait Until Keyword Succeeds    180s    2s    IT ASC - All FSMs Should Have State    false    ${TRUE}
        FOR    ${fsm}    ${name}    IN    &{fsms}
            IT ASC - FSM Status Should Be Valid    ${fsm}    ${name}    false
        END
    FINALLY
        Run Keyword And Continue On Failure    IT ASC - Restore Operation Mode    ${mode}
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
