*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Configure the us-profile of the north port
Documentation    CUST_FACING | Comcast CLI
...              Configure the north port us-profile (rlsp) and commit it (User Guide 3.3).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-011-1]Configure the us-profile of the north port
    [Documentation]
    ...              Step 1. Enter the us-profile view of the north port
    ...              Step 2. Set the rlsp and commit
    ...              Step 3. Show the configuration
    ...              Step 4. Check the configuration in ampapp_data.json
    ...              Step 5. Leave the view
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_us_profile.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure us-profile north    us-profile-north
    ${before}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    show configuration
    ${rlsp_set}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    rlsp 8.10
    ${commit}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    commit
    ${after}=    IT COMMON - Run Fdx View Command And Return    us-profile-north    show configuration
    Log    ${after}
    Should Contain    ${after}    8.10
    ${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json
    Should Contain    ${json}    north_port_configuration
    ${exit}=    IT COMMON - Fdx Exit View    us-profile-north
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
