*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Configure the ds-profile of the south port
Documentation    CUST_FACING | Comcast CLI
...              Configure the south port ds-profile (name, start and end frequency and power, step-down, OOB) and commit it (User Guide 3.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-010-1]Configure the ds-profile of the south port
    [Documentation]
    ...              Step 1. Enter the ds-profile view of the south port
    ...              Step 2. Set the name, the frequency and the power range
    ...              Step 3. Set the step-down entry and commit
    ...              Step 4. Show the configuration
    ...              Step 5. Check the configuration in ampapp_data.json
    ...              Step 6. Leave the view
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_ds_profile.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure ds-profile south    ds-profile-south
    ${before}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    show configuration
    ${name}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    name profile-southtest
    ${start_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    start-freq 109000001
    ${end_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    end-freq 1217000001
    ${start_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    start-power 33.1
    ${end_power}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    end-power 50.1
    ${step_freq}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    step-down 0 start-freq 1001000001
    ${step_size}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    step-down 0 size-db 3.0
    ${commit}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    commit
    ${after}=    IT COMMON - Run Fdx View Command And Return    ds-profile-south    show configuration
    Log    ${after}
    Should Contain    ${after}    profile-southtest
    Should Contain    ${after}    109000001
    Should Contain    ${after}    1217000001
    ${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json
    Should Contain    ${json}    south_port_configuration
    ${exit}=    IT COMMON - Fdx Exit View    ds-profile-south
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
