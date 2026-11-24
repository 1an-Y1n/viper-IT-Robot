*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The firmware upgrade over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Send a SET request to perform a firmware upgrade through the software-upgrade tree (User Guide 9.18). The upgrade itself is a step of the bench procedure, so the suite reads the tree and checks that every update type is accepted.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-051-1]GET the software upgrade tree
    [Documentation]
    ...              Step 1. GET software-upgrade
    ...              Step 2. The answer has to hold the fields of the upgrade
    [Tags]    GNMI    BENCH
    VAR    ${sc_log}    ${case_name}-1_get.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    software-upgrade
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    software-upgrade
    Log    ${value}

[CF-051-2]Check that every update type is accepted
    [Documentation]
    ...              Step 1. SET every update type of the User Guide 9.18.2 and read it back
    ...              Step 2. The update type of the answer has to be the one that was set
    [Tags]    GNMI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-2_update_types.log    scope=TEST
    VAR    @{types}    UPDATE_PUSH_ONLY    UPDATE_ROLL_BACK    UPDATE_STAGE_ONLY    UPDATE_ACTIVATE    UPDATE_DEACTIVATE
    FOR    ${type}    IN    @{types}
        ${update}=    Catenate    /software-upgrade/update-type:::string:::    ${type}
        ${set}=    IT COMMON - Gnmi Set And Return    ${{[$update]}}
        Log    ${set}
        Should Contain    ${set}    UPDATE
        ${after}=    IT COMMON - Gnmi Get And Return    software-upgrade
        ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    software-upgrade
        ${current}=    IT COMMON - Get Dict Field    ${value}    update-type
        Should Be Equal    ${current}    ${type}
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
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
