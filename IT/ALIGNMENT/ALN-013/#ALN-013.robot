*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read the whole amp-alignment tree over gNMI
Documentation    ALIGNMENT | GNMI Alignment (DS1 / DS2 / DS3 / US)
...              Retrieve the amp-alignment root container, every alignment stage container, the alignment status and the alignment status update time through gNMI GET (User Guide 9.10.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
@{alignment_types}    ALIGN_DOWNSTREAM_STAGE_1    ALIGN_DOWNSTREAM_STAGE_2    ALIGN_DOWNSTREAM_STAGE_3    ALIGN_UPSTREAM    ALIGN_NETWORK
*** Test Cases ***
[ALN-013-1]GET the amp-alignment root container
    [Documentation]
    ...              Step 1. GET amp-alignment[alignment-type=*]
    ...              Step 2. Check that the answer holds the five alignment types
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_root.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    amp-alignment[alignment-type=*]
    ${values}=    IT COMMON - Gnmi Get All Values    ${response}
    Log    ${values}
    ${types}=    Evaluate    [v.get('alignment-type') for v in $values]    modules=builtins
    Log    ${types}
    Lists Should Be Equal    ${types}    ${alignment_types}    ignore_order=${True}

[ALN-013-2]GET the container, the status and the update time of every stage
    [Documentation]
    ...              Step 1. GET the stage container, the alignment status and the
    ...                      alignment status update time of every alignment type
    ...              Step 2. Check that the status is one of the four known states
    ...              Step 3. Check that the update time is a timestamp, it is empty
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-2_stages.log    scope=TEST
    VAR    @{allowed_statuses}    ALIGN_STATUS_UNALIGNED    ALIGN_STATUS_IN_PROGRESS    ALIGN_STATUS_ALIGNED    ALIGN_STATUS_FAILURE
    FOR    ${type}    IN    @{alignment_types}
        ${container_path}=    Catenate    SEPARATOR=    amp-alignment[alignment-type=${type}]
        ${status_path}=    Catenate    SEPARATOR=    ${container_path}/alignment-status
        ${time_path}=    Catenate    SEPARATOR=    ${container_path}/alignment-status-update-time
        ${container_response}=    IT COMMON - Gnmi Get And Return    ${container_path}
        ${container}=    IT COMMON - Gnmi Get Leaf Value    ${container_response}    ${container_path}
        IT COMMON - Gnmi Leaf Should Exist    ${container}    alignment-status
        IT COMMON - Gnmi Leaf Should Exist    ${container}    alignment-status-update-time
        Should Be Equal    ${container}[alignment-type]    ${type}
        ${status_response}=    IT COMMON - Gnmi Get And Return    ${status_path}
        ${status}=    IT COMMON - Gnmi Get Leaf Value    ${status_response}    ${status_path}
        IT COMMON - Value Should Be One Of    ${status}    ${allowed_statuses}
        Should Be Equal    ${status}    ${container}[alignment-status]
        ${time_response}=    IT COMMON - Gnmi Get And Return    ${time_path}
        ${time}=    IT COMMON - Gnmi Get Leaf Value    ${time_response}    ${time_path}
        ${is_stamp}=    Evaluate    isinstance($time, str)    modules=builtins
        Should Be True    ${is_stamp}
        Should Be Equal    ${time}    ${container}[alignment-status-update-time]
        IF    $time != ''
            Evaluate    datetime.datetime.fromisoformat($time.replace('Z', '+00:00'))    modules=datetime
        ELSE IF    $status == 'ALIGN_STATUS_ALIGNED'
            Fail    ${type} is ALIGNED but its update time is empty
        END
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
