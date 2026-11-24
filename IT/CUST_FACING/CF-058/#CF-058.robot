*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The SSH authentication settings and the idle timeout
Documentation    CUST_FACING | SSH (Ch14)
...              Verify the SSH password authentication, the public key authentication and the idle timeout (User Guide 14.2). The suite reads the settings and the idle timeout; it does not disable the password authentication, because that would take the bench away.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-058-1]Read the authentication settings and the idle timeout
    [Documentation]
    ...              Step 1. Run debug ssh show auths
    ...              Step 2. Run debug ssh show idle-timeout
    [Tags]    CLI    BENCH
    VAR    ${sc_log}    ${case_name}-1_settings.log    scope=TEST
    ${auths}=    IT COMMON - Run Fdx Command And Return    debug ssh show auths
    Log    ${auths}
    Should Not Be Equal    ${auths}    ${EMPTY}
    ${timeout}=    IT COMMON - Run Fdx Command And Return    debug ssh show idle-timeout
    Log    ${timeout}
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
