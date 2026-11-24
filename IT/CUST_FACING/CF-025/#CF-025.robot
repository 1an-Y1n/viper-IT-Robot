*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The downstream spectrum capture after a firmware downgrade
Documentation    CUST_FACING | DS Output Spectrum Before and After FW Upgrade
...              Capture the downstream spectrum with the WBFFT capture of the firmware that is in place and compare it with the capture of the reference firmware (User Guide 13). The downgrade itself is a step of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${capture_file}    /mnt/nonvol_active/wbfft_capture_after_fw_downgrade.txt
${reference_file}    /mnt/nonvol_active/wbfft_capture_before_fw_upgrade.txt
*** Test Cases ***
[CF-025-1]Run the WBFFT capture of the firmware in place
    [Documentation]
    ...              Step 1. Run the WBFFT capture and write it to a file
    ...              Step 2. Check that the file holds the capture
    [Tags]    CLI    FILE    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_capture.log    scope=TEST
    ${capture}=    IT COMMON - Run Dut Command And Return    sc_cli wbfft_capture 0 1218000000 32768 1647000000 FreqDomainPower None Time 6 200 Dp0 false 0 1 1000 > ${capture_file}    timeout=300
    Log    ${capture}
    ${size}=    IT COMMON - Wait For File On Dut    ${capture_file}    timeout=120
    Should Not Be Equal    ${size}    0

[CF-025-2]Compare the two captures
    [Documentation]
    ...              Step 1. Read the capture of the reference firmware
    ...              Step 2. Read the capture of the firmware in place
    ...              Step 3. Both have to hold the same number of bins
    [Tags]    FILE    BENCH
    VAR    ${sc_log}    ${case_name}-2_compare.log    scope=TEST
    ${reference}=    IT COMMON - Run Dut Command And Return    cat ${reference_file}
    ${current}=    IT COMMON - Run Dut Command And Return    cat ${capture_file}
    Should Not Be Equal    ${reference}    ${EMPTY}
    Should Not Be Equal    ${current}    ${EMPTY}
    ${reference_bins}=    Evaluate    len($reference.split())    modules=builtins
    ${current_bins}=    Evaluate    len($current.split())    modules=builtins
    Should Be Equal    ${current_bins}    ${reference_bins}
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
