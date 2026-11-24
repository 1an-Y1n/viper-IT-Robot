*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read the SP DS ATT over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Read the SP_DS_ATT rf-component over the two downstream attenuation paths (User Guide 9.2.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-044-1]GET the SP DS attenuation over both paths
    [Documentation]
    ...              Step 1. GET the non-volatile attenuation
    ...              Step 2. GET the volatile attenuation
    ...              Step 3. Compare both with sc_rfboard_cli
    [Tags]    GNMI    CLI
    VAR    ${sc_log}    ${case_name}-1_get.log    scope=TEST
    VAR    @{paths}    /rf-components/ds-output-port-atten[port=AMP_PORT_MAIN]/attenuation-db    /rf-components/ds-output-port-atten-volatile[port=AMP_PORT_MAIN]/attenuation-db
    FOR    ${path}    IN    @{paths}
        ${response}=    IT COMMON - Gnmi Get And Return    ${path}
        ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}
        Log    ${value}
    END
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2
    Log    ${cli}
    Should Contain    ${cli}    SP_DS_ATT
    ${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json
    Should Contain    ${json}    sp_ds_att_attenuation_db
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
