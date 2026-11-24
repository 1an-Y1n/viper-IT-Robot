*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The North AFE backoff is mapped to the interference ratio
Documentation    CHANGELIST | PAB
...              palGetNorthAfeBackOff and palSetNorthAfeBackOff are mapped to the downstream_plus_interference_to_downstream_ratio_db of the configuration (CAMP-2542).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-025-1]Read the two keys of the north port configuration
    [Documentation]
    ...              Step 1. Read the two keys of /mnt/sc_nonvol/ampapp_data.json
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-1_baseline.log    scope=TEST
    ${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json
    ${north}=    IT COMMON - Get Dict Field    ${parsed}    north_port_configuration
    ${ratio}=    IT COMMON - Get Dict Field    ${north}    downstream_plus_interference_to_downstream_ratio_db
    ${backoff}=    IT COMMON - Get Dict Field    ${north}    rx_adc_backoff_db
    Log    ${ratio}
    Log    ${backoff}

[CL-025-2]Set the AFE backoff and check the mapping
    [Documentation]
    ...              Step 1. Set the North AFE backoff to 3 dB
    ...              Step 2. Read the two keys again, the ratio has to be 3 and the backoff must not have moved
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-2_mapping.log    scope=TEST
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_north_afe_back_off 3
    Log    ${set}
    ${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json
    ${north}=    IT COMMON - Get Dict Field    ${parsed}    north_port_configuration
    ${ratio}=    IT COMMON - Get Dict Field    ${north}    downstream_plus_interference_to_downstream_ratio_db
    Should Be Equal As Integers    ${ratio}    3
    ${backoff}=    IT COMMON - Get Dict Field    ${north}    rx_adc_backoff_db
    Should Not Be Equal    ${backoff}    3
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
