*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read the ds-profile of the south port over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Read the ds-profile of the south port over gNMI and compare it with the north port (User Guide 9.3).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-038-1]GET the ds-profile of the south port and compare it with the north port
    [Documentation]
    ...              Step 1. GET the ds-profile of the south port
    ...              Step 2. GET the ds-profile of the north port
    ...              Step 3. The two have to carry the same values
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_get.log    scope=TEST
    ${south}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]
    ${south_value}=    IT COMMON - Gnmi Get Leaf Value    ${south}    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]
    ${north}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]
    ${north_value}=    IT COMMON - Gnmi Get Leaf Value    ${north}    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]
    ${south_name}=    IT COMMON - Get Dict Field    ${south_value}    data-set-name
    ${north_name}=    IT COMMON - Get Dict Field    ${north_value}    data-set-name
    Should Be Equal    ${south_name}    ${north_name}
    ${south_min}=    IT COMMON - Get Dict Field    ${south_value}    min-frequency-hertz
    ${north_min}=    IT COMMON - Get Dict Field    ${north_value}    min-frequency-hertz
    Should Be Equal    ${south_min}    ${north_min}
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
