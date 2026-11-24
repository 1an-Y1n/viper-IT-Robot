*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The SSH login with special characters in the password
Documentation    CHANGELIST | CUST_FACING
...              The SSH login has to work when the password holds special characters (DZ300-1876).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-018-1]Record the baseline of the user database
    [Documentation]
    ...              Step 1. Count the lines of /etc/passwd
    ...              Step 2. Back up /etc/passwd and /etc/shadow
    [Tags]    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_baseline.log    scope=TEST
    ${count}=    IT COMMON - Run Dut Command And Return    grep -c . /etc/passwd
    Log    ${count}
    ${backup}=    IT COMMON - Run Dut Command And Return    cp /etc/passwd /tmp/passwd.backup && cp /etc/shadow /tmp/shadow.backup
    Log    ${backup}

[CL-018-2]Check the rules of the user names
    [Documentation]
    ...              Step 1. Create a user with a valid name
    ...              Step 2. Read the user database, the user has to be there
    ...              Step 3. Create a user with an invalid name, it has to be refused
    ...              Step 4. Remove the valid user again
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_usernames.log    scope=TEST
    ${valid}=    IT COMMON - Run Fdx Command And Return    configure username ituser1 password Pw4920a
    Log    ${valid}
    Should Contain    ${valid}    ituser1
    ${users}=    IT COMMON - Run Fdx Command And Return    debug login show configured-users-db
    Log    ${users}
    Should Contain    ${users}    ituser1
    ${invalid}=    IT COMMON - Run Fdx Command And Return    configure username .baduser password Pw4920a
    Log    ${invalid}
    ${remove}=    IT COMMON - Run Fdx Command And Return    configure username ituser1 no
    Log    ${remove}

[CL-018-3]Check a password with a special character
    [Documentation]
    ...              Step 1. Create a user whose password holds a special character
    ...              Step 2. Read the user database, the user has to be there
    ...              Step 3. Remove the user again
    ...              Step 4. Put the user database back
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-3_password.log    scope=TEST
    ${create}=    IT COMMON - Run Fdx Command And Return    configure username ituser2 password swpa&4920
    Log    ${create}
    Should Contain    ${create}    ituser2
    ${users}=    IT COMMON - Run Fdx Command And Return    debug login show configured-users-db
    Should Contain    ${users}    ituser2
    ${remove}=    IT COMMON - Run Fdx Command And Return    configure username ituser2 no
    ${restore}=    IT COMMON - Run Dut Command And Return    cp /tmp/passwd.backup /etc/passwd && cp /tmp/shadow.backup /etc/shadow
    Log    ${restore}
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
