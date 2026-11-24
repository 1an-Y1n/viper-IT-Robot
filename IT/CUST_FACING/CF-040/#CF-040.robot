*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set the rlsp of the south port over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Read the us-profile of the south port and set its rlsp-dbmv over gNMI (User Guide 9.3.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-040-1]SET the rlsp of the south port
    [Documentation]
    ...              Step 1. GET the us-profile of the south port
    ...              Step 2. SET the rlsp-dbmv
    ...              Step 3. GET it again and check that it took
    ...              Step 4. Check the value in ampapp_data.json
    [Tags]    GNMI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_set.log    scope=TEST
    VAR    @{updates}    /us-profile/us-port-configuration[port=AMP_PORT_SOUTH]/rlsp-dbmv:::float:::10
    ${before}=    IT COMMON - Gnmi Get And Return    /us-profile/us-port-configuration[port=AMP_PORT_SOUTH]
    ${set}=    IT COMMON - Gnmi Set And Return    ${updates}
    Log    ${set}
    Should Contain    ${set}    UPDATE
    ${after}=    IT COMMON - Gnmi Get And Return    /us-profile/us-port-configuration[port=AMP_PORT_SOUTH]
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    /us-profile/us-port-configuration[port=AMP_PORT_SOUTH]
    ${rlsp}=    IT COMMON - Get Dict Field    ${value}    rlsp-dbmv
    Should Be Equal As Integers    ${rlsp}    10
    ${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json
    Should Contain    ${json}    south_port_configuration
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
