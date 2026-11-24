*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Configure the spectrum allocation
Documentation    CUST_FACING | Comcast CLI
...              Configure the spectrum allocation (the downstream, the legacy upstream and the extended upstream frequency range, the subband modes) and commit it (User Guide 3.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-013-1]Configure the spectrum allocation and commit it
    [Documentation]
    ...              Step 1. Enter the spectrum view
    ...              Step 2. Set the frequency ranges
    ...              Step 3. Set the three subbands and add a fourth one
    ...              Step 4. Commit and show the configuration
    ...              Step 5. Check the allocation in ampapp_data.json
    ...              Step 6. Leave the view
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_spectrum.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum
    ${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
    ${ds_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-start-freq 108000000
    ${ds_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-end-freq 1218000000
    ${us_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-start-freq 5000000
    ${us_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-end-freq 85000000
    ${ext_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-start-freq 108000000
    ${ext_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-end-freq 396000000
    ${sub0}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 0 ds
    ${sub1}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 1 ds
    ${sub2}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 2 ds
    ${add}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband add bidi
    ${remove}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband remove 3
    ${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit
    ${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration
    Log    ${after}
    Should Contain    ${after}    108000000
    Should Contain    ${after}    1218000000
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_spectrum_allocation
    Log    ${cli}
    Should Contain    ${cli}    dsBeginHz: 108000000
    Should Contain    ${cli}    dsEndHz: 1218000000
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
