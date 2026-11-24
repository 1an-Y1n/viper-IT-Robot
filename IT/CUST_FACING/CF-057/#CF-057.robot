*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The login banner
Documentation    CUST_FACING | SSH (Ch14)
...              Verify that the SSH login banner can be configured and removed (User Guide 14.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-057-1]Configure the login banner and remove it again
    [Documentation]
    ...              Step 1. Write the banner text and end it with a line that holds only /end
    ...              Step 2. Check that the banner was configured
    ...              Step 3. Open a new session and check that the banner is in it
    ...              Step 4. Remove the banner again
    ...              Step 5. Open a new session and check that the banner is gone
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_banner.log    scope=TEST
    ${enter}=    IT COMMON - Run Fdx Command And Return Buffer    configure banner login    timeout=5
    Log    ${enter}
    Should Contain    ${enter}    Enter TEXT message
    ${line1}=    IT COMMON - Run Fdx Command And Return Buffer    This is the login banner of the IT suite    timeout=5
    Log    ${line1}
    ${end}=    IT COMMON - Run Fdx Command And Return    /end
    Log    ${end}
    Should Contain    ${end}    Login banner configured.
    ${banner}=    IT COMMON - Get Dut Login Banner
    Log    ${banner}
    Should Contain    ${banner}    This is the login banner of the IT suite
    ${remove}=    IT COMMON - Run Fdx Command And Return    configure banner login no
    Log    ${remove}
    Should Contain    ${remove}    Login banner cleared.
    ${after}=    IT COMMON - Get Dut Login Banner
    Log    ${after}
    Should Not Contain    ${after}    This is the login banner of the IT suite
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
