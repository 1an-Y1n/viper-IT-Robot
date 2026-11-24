*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The ASC runs without a calibration snapshot
Documentation    ASC | Robustness
...              Verify the behaviour of the ASC when the calibration snapshot is lost (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-037-1]Remove the calibration snapshot and restart the daemon
    [Documentation]
    ...              Step 1. Remove /mnt/sc_nonvol/asc_calib_snapshot.json
    ...              Step 2. Restart the sc-asc daemon
    ...              Step 3. Check that the daemon runs
    ...              Step 4. Read the ASC configuration
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_snapshot_lost.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol/asc_calib_snapshot.json
    Log    ${before}
    ${existed}=    Evaluate    'No such file' not in $before    modules=builtins
    IF    $existed
        ${backup}=    IT COMMON - Run Dut Command And Return    cp /mnt/sc_nonvol/asc_calib_snapshot.json /tmp/asc_calib_snapshot.backup
        ${remove}=    IT COMMON - Run Dut Command And Return    rm -f /mnt/sc_nonvol/asc_calib_snapshot.json
    END
    ${restart}=    IT COMMON - Run Dut Command And Return    systemctl restart sc-asc    timeout=60
    Log    ${restart}
    ${status}=    IT COMMON - Wait For Dut Command Contains    systemctl is-active sc-asc    active    timeout=60
    Should Contain    ${status}    active
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Log    ${config}
    IF    $existed
        ${restore}=    IT COMMON - Run Dut Command And Return    cp /tmp/asc_calib_snapshot.backup /mnt/sc_nonvol/asc_calib_snapshot.json
        ${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/asc_calib_snapshot.json    timeout=60
        Should Not Be Equal    ${size}    0
    END
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
