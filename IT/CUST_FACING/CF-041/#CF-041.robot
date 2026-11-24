*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set the spectrum allocation over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Set the spectrum allocation to the Midsplit 1.2GHz with the frequency exclusions over gNMI (User Guide 9.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-041-1]GET and SET the spectrum allocation over gNMI
    [Documentation]
    ...              Step 1. GET /spectrum-allocation
    ...              Step 2. SET the allocation
    ...              Step 3. GET it again and check the values
    ...              Step 4. Check the values in ampapp_data.json
    [Tags]    GNMI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_set.log    scope=TEST
    VAR    @{updates}    /spectrum-allocation/ds-begin-hz:::uint:::108000000    /spectrum-allocation/ds-end-hz:::uint:::1218000000    /spectrum-allocation/us-legacy-begin-hz:::uint:::5000000    /spectrum-allocation/us-legacy-end-hz:::uint:::85000000    /spectrum-allocation/us-extended-begin-hz:::uint:::108000000    /spectrum-allocation/us-extended-end-hz:::uint:::684000000    /spectrum-allocation/subband-modes[subband-index=0]/subband-mode:::string:::SUBBAND_MODE_BIDIRECTIONAL    /spectrum-allocation/subband-modes[subband-index=1]/subband-mode:::string:::SUBBAND_MODE_BIDIRECTIONAL    /spectrum-allocation/subband-modes[subband-index=2]/subband-mode:::string:::SUBBAND_MODE_BIDIRECTIONAL    /spectrum-allocation/frequency-exclusions[index=0]/start-hz:::uint:::383000000    /spectrum-allocation/frequency-exclusions[index=0]/end-hz:::uint:::396000000    /spectrum-allocation/frequency-exclusions[index=0]/ds-fe-type:::string:::DS_FE_PASS_OTHER    /spectrum-allocation/frequency-exclusions[index=0]/us-fe-type:::string:::US_FE_EXCLUDED
    ${before}=    IT COMMON - Gnmi Get And Return    /spectrum-allocation
    ${set}=    IT COMMON - Gnmi Set And Return    ${updates}
    Log    ${set}
    Should Contain    ${set}    UPDATE
    ${after}=    IT COMMON - Gnmi Get And Return    /spectrum-allocation
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    /spectrum-allocation
    ${ds_begin}=    IT COMMON - Get Dict Field    ${value}    ds-begin-hz
    Should Be Equal As Integers    ${ds_begin}    108000000
    ${ds_end}=    IT COMMON - Get Dict Field    ${value}    ds-end-hz
    Should Be Equal As Integers    ${ds_end}    1218000000
    ${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json
    Should Contain    ${json}    spectrum
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
