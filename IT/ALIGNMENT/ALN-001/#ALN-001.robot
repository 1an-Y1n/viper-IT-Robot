*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Run the NAFE calibration of the two NAFE blocks and of both of them
Documentation    ALIGNMENT | Sercomm CLI Calibration
...              Run sc_cli calib_nafe for NAFE_BO1, NAFE_BO2 and ALLNAFE and check that each calibration completes without error (User Guide 3.5, 7.2.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ALN-001-1]Calibrate the NAFE block 1
    [Documentation]
    ...              Step 1. Run sc_cli calib_nafe NAFE_BO1
    ...              Step 2. Check that the calibration succeeded
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-nafe_bo1.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    sc_cli calib_nafe NAFE_BO1    timeout=120
    Log    ${out}
    Should Contain    ${out}    calib_nafe success    msg=the calibration of the NAFE block 1 did not end with the success marker
    Should Not Contain    ${out}    failed    msg=the calibration of the NAFE block 1 reported a failure

[ALN-001-2]Calibrate the NAFE block 2
    [Documentation]
    ...              Step 1. Run sc_cli calib_nafe NAFE_BO2
    ...              Step 2. Check that the calibration succeeded
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-nafe_bo2.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    sc_cli calib_nafe NAFE_BO2    timeout=120
    Log    ${out}
    Should Contain    ${out}    calib_nafe success    msg=the calibration of the NAFE block 2 did not end with the success marker
    Should Not Contain    ${out}    failed    msg=the calibration of the NAFE block 2 reported a failure

[ALN-001-3]Calibrate both NAFE blocks
    [Documentation]
    ...              Step 1. Run sc_cli calib_nafe ALLNAFE
    ...              Step 2. Check that the calibration succeeded
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-allnafe.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    sc_cli calib_nafe ALLNAFE    timeout=120
    Log    ${out}
    Should Contain    ${out}    calib_nafe success    msg=the calibration of both NAFE blocks did not end with the success marker
    Should Not Contain    ${out}    failed    msg=the calibration of both NAFE blocks reported a failure
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
    # the suite has nothing to clean up
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
