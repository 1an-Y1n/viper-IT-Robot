*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Trigger the ALIGN_DOWNSTREAM_STAGE_1 alignment over gNMI
Documentation    ALIGNMENT | GNMI Alignment (DS1 / DS2 / DS3 / US)
...              Trigger the alignment stage ALIGN_DOWNSTREAM_STAGE_1 through a gNMI SET and verify the ON_CHANGE status sequence (User Guide 9.10). Triggering a stage may invalidate later stages.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${alignment_type}    ALIGN_DOWNSTREAM_STAGE_1
*** Test Cases ***
[ALN-009-1]Trigger ALIGN_DOWNSTREAM_STAGE_1 and subscribe to its alignment status
    [Documentation]
    ...              Step 1. Wait until no alignment stage is in progress and check prerequisites
    ...              Step 2. Start the ON_CHANGE subscription and wait for synchronization
    ...              Step 3. Trigger the stage with gNMI SET
    ...              Step 4. Verify IN_PROGRESS followed by ALIGNED; FAILURE fails the test
    [Tags]    GNMI    WRITE
    VAR    ${sc_log}    ${case_name}-alignment_align_downstream_stage_1.log    scope=TEST
    VAR    ${path}    amp-alignment[alignment-type=ALIGN_DOWNSTREAM_STAGE_1]
    VAR    ${status_path}    amp-alignment[alignment-type=ALIGN_DOWNSTREAM_STAGE_1]/alignment-status
    VAR    @{prerequisites}    
    ${idle}=    IT COMMON - Wait For No Gnmi Instance With    amp-alignment[alignment-type=*]    alignment-status    ALIGN_STATUS_IN_PROGRESS    timeout=300
    FOR    ${prior}    IN    @{prerequisites}
        ${prior_path}=    Catenate    SEPARATOR=    amp-alignment[alignment-type=${prior}]/alignment-status
        ${prior_response}=    IT COMMON - Gnmi Get And Return    ${prior_path}
        ${prior_status}=    IT COMMON - Gnmi Get Leaf Value    ${prior_response}    ${prior_path}
        Should Be Equal    ${prior_status}    ALIGN_STATUS_ALIGNED    msg=Prerequisite ${prior} is ${prior_status}, not ALIGNED
    END
    GNMI_IT.Start Subscription    ${status_path}    log_name=${sc_log}
    ${update}=    Catenate    SEPARATOR=    /    ${path}    /alignment-type:::string:::${alignment_type}
    ${result}=    GNMI_IT.Set And Return    updates=${update}    resp_timeout=30    log_name=${sc_log}
    Should Be Equal    ${result}[results][0][operation]    UPDATE
    Should Be Equal    ${result}[results][0][path]    ${path}/alignment-type
    ${started}=    GNMI_IT.Next Subscription Response    timeout=120
    ${started_status}=    IT COMMON - Gnmi Get Leaf Value    ${started}    ${status_path}
    Should Be Equal    ${started_status}    ALIGN_STATUS_IN_PROGRESS
    ${deadline}=    Evaluate    time.monotonic() + 300    modules=time
    WHILE    True
        ${remaining}=    Evaluate    $deadline - time.monotonic()    modules=time
        IF    $remaining <= 0    Fail    Alignment did not finish within 300 seconds
        ${finished}=    GNMI_IT.Next Subscription Response    timeout=${remaining}
        ${finished_status}=    IT COMMON - Gnmi Get Leaf Value    ${finished}    ${status_path}
        IF    $finished_status == 'ALIGN_STATUS_ALIGNED'    BREAK
        Should Be Equal    ${finished_status}    ALIGN_STATUS_IN_PROGRESS
    END
    GNMI_IT.Stop Subscription
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
