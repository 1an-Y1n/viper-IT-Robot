*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The downstream spectrum capture before a firmware upgrade
Documentation    CUST_FACING | DS Output Spectrum Before and After FW Upgrade
...              Capture the downstream spectrum with the WBFFT capture of the firmware that is in place (User Guide 13). The firmware upgrade that the template asks for is a step of the bench procedure, so the suite runs the capture and the comparison of the two captures it finds.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${capture_file}    /mnt/nonvol_active/wbfft_capture_before_fw_upgrade.txt
*** Test Cases ***
[CF-024-1]Run the WBFFT capture of the current firmware
    [Documentation]
    ...              Step 1. Run the WBFFT capture and write it to a file
    ...              Step 2. Check that the file holds the capture
    [Tags]    CLI    FILE    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_capture.log    scope=TEST
    ${capture}=    IT COMMON - Run Dut Command And Return    sc_cli wbfft_capture 0 1218000000 32768 1647000000 FreqDomainPower None Time 6 200 Dp0 false 0 1 1000 > ${capture_file}    timeout=300
    Log    ${capture}
    ${size}=    IT COMMON - Wait For File On Dut    ${capture_file}    timeout=120
    Should Not Be Equal    ${size}    0
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
