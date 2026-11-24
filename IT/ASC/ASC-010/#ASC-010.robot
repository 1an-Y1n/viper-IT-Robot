*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Clear the calibration snapshot
Documentation    ASC | Config/Target Data clear
...              Verify that asc_calib_snapshot clear removes the calibration snapshot (User Guide 10.4). The calibration that the template asks for is a step of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-010-1]Clear the calibration snapshot and check it
    [Documentation]
    ...              Step 1. Run sc_cli asc_calib_snapshot show, there has to be data
    ...              Step 2. Run sc_cli asc_calib_snapshot clear
    ...              Step 3. Run show again, it has to report no calibration
    ...              Step 4. Check that the snapshot file is gone
    [Tags]    CLI    FILE    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_clear.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    Log    ${before}
    ${clear}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot clear
    Log    ${clear}
    Should Contain    ${clear}    asc_calib_snapshot clear done
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    Log    ${after}
    ${end_freq}=    IT COMMON - Get Cli Field Or Default    ${after}    ds_end_frequency_hz    0
    Should Be Equal    ${end_freq}    0
    ${out}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol/asc_calib_snapshot.json
    Log    ${out}
    Should Contain    ${out}    No such file
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
