*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Add and remove a frequency exclusion
Documentation    CUST_FACING | Comcast CLI
...              Add and remove a frequency exclusion and commit it (User Guide 3.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-014-1]Add a frequency exclusion and commit it
    [Documentation]
    ...              Step 1. Enter the spectrum view
    ...              Step 2. Add the frequency exclusion and commit it
    ...              Step 3. Check the exclusion in sc_cli get_spectrum_allocation
    ...              Step 4. Leave the view
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_add.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum
    ${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
    ${add}=    IT COMMON - Run Fdx View Command And Return    spectrum    add freq-exclusion 150000000 200000000 PASS_OTHER INTERFERENCE
    ${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit
    ${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
    Log    ${after}
    Should Contain    ${after}    150000000
    Should Contain    ${after}    200000000
    ${exit}=    IT COMMON - Fdx Exit View    spectrum

[CF-014-2]Remove the frequency exclusion and commit it
    [Documentation]
    ...              Step 1. Enter the spectrum view
    ...              Step 2. Remove the frequency exclusion and commit it
    ...              Step 3. Check the exclusion in sc_cli get_spectrum_allocation
    ...              Step 4. Leave the view
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_remove.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum
    ${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
    ${remove}=    IT COMMON - Run Fdx View Command And Return    spectrum    remove freq-exclusion 0
    ${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit
    ${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
    Log    ${after}
    ${exit}=    IT COMMON - Fdx Exit View    spectrum
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
