*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Check the factory files, the non-volatile files and the EC PNM statistics
Documentation    CUST_FACING | System & Basic Configuration
...              Verify that the mandatory factory and non-volatile files exist and that the Broadcom EC PNM statistics can be collected (User Guide 2.1, 2.2, 10.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-007-1]Check the mandatory factory files
    [Documentation]
    ...              Step 1. Check the factory files of the 1.2G band
    ...              Step 2. Check the factory files of the 1.8G band, they are optional
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-1_factory_files.log    scope=TEST
    ${mandatory}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_factory/MainBID.json /mnt/sc_factory/AmpMFGID.json /mnt/sc_factory/SP_DTS_OUT_1p2G_Mode.DAT /mnt/sc_factory/SF_WBFFT_ADC_DP0_Factory_1p2G_Mode.txt /mnt/sc_factory/SF_WBFFT_ADC_DP0_Factory_1p2G_Mode_Temp.txt
    Log    ${mandatory}
    Should Not Contain    ${mandatory}    No such file
    ${optional}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_factory/SP_DTS_OUT_1p8G_Mode.DAT /mnt/sc_factory/SF_WBFFT_ADC_DP0_Factory_1p8G_Mode.txt /mnt/sc_factory/SF_WBFFT_ADC_DP0_Factory_1p8G_Mode_Temp.txt
    Log    ${optional}

[CF-007-2]Check the non-volatile files
    [Documentation]
    ...              Step 1. Check the non-volatile files of the DUT
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-2_nonvol_files.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol/ampapp_data.json /mnt/sc_nonvol/rfboard_data.json /mnt/sc_nonvol/rfboard_data.json.default /mnt/sc_nonvol/sc_amp_cfg.json /mnt/sc_nonvol/s2p_files
    Log    ${out}
    Should Not Contain    ${out}    No such file

[CF-007-3]Collect the EC PNM statistics
    [Documentation]
    ...              Step 1. Run the EC PNM statistics command through the Broadcom CLI wrapper
    ...              Step 2. The command has to complete
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-3_ec_pnm.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    cliwrapper_client -c '/ec_pnm_stats 6 0' -s /tmp/brcmhal.sock -t 2000    timeout=60
    Log    ${out}
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
