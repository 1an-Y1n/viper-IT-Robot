*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Show and set the rf-components through the clish
Documentation    CUST_FACING | Comcast CLI
...              Show all the rf-components through the clish and set the ones that the clish supports (User Guide 3.6). The template notes that the clish rf-component is not fully supported yet.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-016-1]Show the rf-components
    [Documentation]
    ...              Step 1. Enter the rf-components view
    ...              Step 2. Show the rf-components
    ...              Step 3. Leave the view
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_show.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    rf-components    rf-components
    ${show}=    IT COMMON - Run Fdx View Command And Return    rf-components    show rf-components
    Log    ${show}
    Should Not Be Equal    ${show}    ${EMPTY}
    ${exit}=    IT COMMON - Fdx Exit View    rf-components

[CF-016-2]Check the rf-components with the Sercomm CLI
    [Documentation]
    ...              Step 1. Read the PA current, the attenuation and the tilt of the RF board
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_sc_rfboard.log    scope=TEST
    ${pa}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_pa_current 0
    ${atten}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
    ${tilt}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0
    Log    ${pa}
    Should Contain    ${pa}    DS_HYBRID_PA_BIAS
    Should Contain    ${atten}    NP_DS_ATT_BEFORE_LNA
    Should Contain    ${tilt}    SP_DS_1.2G_VEQ

[CF-016-3]Check the rf-components in rfboard_data.json
    [Documentation]
    ...              Step 1. Read rfboard_data.json
    ...              Step 2. The file has to hold the attenuation, the tilt and the bias values
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-3_rfboard_data.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json
    Log    ${out}
    Should Contain    ${out}    atten
    Should Contain    ${out}    tilt
    Should Contain    ${out}    bias
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
