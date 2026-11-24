*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Show the rf-components over gNMI and over the clish
Documentation    CUST_FACING | GNMI Tests
...              Display all the available rf-components (User Guide 9.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-042-1]GET the rf-components over gNMI
    [Documentation]
    ...              Step 1. GET /rf-components
    ...              Step 2. The answer has to hold the components of the User Guide 9.2.1 table
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_get.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    /rf-components
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    /rf-components
    Log    ${value}
    IT COMMON - Gnmi Leaf Should Exist    ${value}    ds-output-port-atten
    IT COMMON - Gnmi Leaf Should Exist    ${value}    us-fdx-attenuation-db
    IT COMMON - Gnmi Leaf Should Exist    ${value}    north-port-switch-path

[CF-042-2]GET the rf-components that have no table of their own
    [Documentation]
    ...              Step 1. GET the five components of the User Guide 9.2.1 note
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-2_uncovered.log    scope=TEST
    VAR    @{paths}    /rf-components/north-afe-equalization-db[index=0]/equalization-db    /rf-components/north-afe-equalization-db[index=1]/equalization-db    /rf-components/us-fdx-input-attenuation-db[port=AMP_PORT_MAIN]/attenuation-db    /rf-components/north-us-pa-bias    /rf-components/south-ds-pa-bias
    FOR    ${path}    IN    @{paths}
        ${response}=    IT COMMON - Gnmi Get And Return    ${path}
        ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}
        Log    ${value}
    END

[CF-042-3]Show the rf-components through the clish
    [Documentation]
    ...              Step 1. Enter the rf-components view
    ...              Step 2. Show the rf-components
    ...              Step 3. Leave the view
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-3_clish.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    rf-components    rf-components
    ${show}=    IT COMMON - Run Fdx View Command And Return    rf-components    show rf-components
    Log    ${show}
    Should Not Be Equal    ${show}    ${EMPTY}
    ${exit}=    IT COMMON - Fdx Exit View    rf-components
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
