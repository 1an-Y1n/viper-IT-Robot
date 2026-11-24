*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set and read the ds-profile of both ports over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Use a gNMI request to SET and GET the ds-profile of the north-port-configuration (User Guide 9.3). The two ports have to carry the same configuration.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-037-1]GET the ds-profile of both ports
    [Documentation]
    ...              Step 1. GET the ds-profile of the two ports
    ...              Step 2. Both answers have to hold a data-set-name
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_get.log    scope=TEST
    ${north}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]
    ${north_value}=    IT COMMON - Gnmi Get Leaf Value    ${north}    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]
    ${south}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]
    ${south_value}=    IT COMMON - Gnmi Get Leaf Value    ${south}    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]
    Log    ${north_value}
    Log    ${south_value}

[CF-037-2]SET the ds-profile of both ports in one atomic request
    [Documentation]
    ...              Step 1. SET the ds-profile of the north and of the south port
    ...              Step 2. GET both ports again and compare the values
    [Tags]    GNMI    WRITE
    VAR    ${sc_log}    ${case_name}-2_set.log    scope=TEST
    VAR    @{updates}    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/data-set-name:::string:::TEST_PROFILE    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/ds-power-min-freq-dbmv:::float:::26.00    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/ds-power-max-freq-dbmv:::float:::45.00    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/min-frequency-hertz:::uint:::108000000    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/max-frequency-hertz:::uint:::1217000000    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/data-set-name:::string:::TEST_PROFILE    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/ds-power-min-freq-dbmv:::float:::26.00    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/ds-power-max-freq-dbmv:::float:::45.00    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/min-frequency-hertz:::uint:::108000000    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/max-frequency-hertz:::uint:::1217000000    /ds-profile/step[step-index=0]/step-db:::float:::0    /ds-profile/step[step-index=0]/step-frequency-hz:::uint:::1002000000
    ${set}=    IT COMMON - Gnmi Set And Return    ${updates}
    Log    ${set}
    Should Contain    ${set}    UPDATE
    ${north}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]
    ${north_value}=    IT COMMON - Gnmi Get Leaf Value    ${north}    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]
    ${south}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]
    ${south_value}=    IT COMMON - Gnmi Get Leaf Value    ${south}    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]
    ${north_name}=    IT COMMON - Get Dict Field    ${north_value}    data-set-name
    ${south_name}=    IT COMMON - Get Dict Field    ${south_value}    data-set-name
    Should Be Equal    ${north_name}    TEST_PROFILE
    Should Be Equal    ${south_name}    TEST_PROFILE
    ${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json
    Should Contain    ${json}    north_port_configuration
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
