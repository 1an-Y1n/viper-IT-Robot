*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The user and the key management
Documentation    CUST_FACING | SSH (Ch14)
...              Verify the user management, the client public key management, the host public key management and the live sessions (User Guide 14.3, 14.4, 14.5, 14.6).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-059-1]Add a user and remove it again
    [Documentation]
    ...              Step 1. Create the user test3 with a password
    ...              Step 2. Read the configured users
    ...              Step 3. Remove the user again
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_user.log    scope=TEST
    ${clean}=    IT COMMON - Run Fdx Command And Return    configure username test3 no
    Log    ${clean}
    ${add}=    IT COMMON - Run Fdx Command And Return    configure username test3 password test3
    Log    ${add}
    ${users}=    IT COMMON - Run Fdx Command And Return    debug login show configured-users-db
    Log    ${users}
    Should Contain    ${users}    user=test3,
    ${remove}=    IT COMMON - Run Fdx Command And Return    configure username test3 no
    Log    ${remove}
    ${after}=    IT COMMON - Run Fdx Command And Return    debug login show configured-users-db
    Should Not Contain    ${after}    user=test3,

[CF-059-2]Read the live sessions
    [Documentation]
    ...              Step 1. Run show users
    ...              Step 2. The answer has to list the live sessions
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_sessions.log    scope=TEST
    ${out}=    IT COMMON - Run Fdx Command And Return    show users
    Log    ${out}
    Should Not Be Equal    ${out}    ${EMPTY}
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
