*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The AMP recovers from a corrupted agc_data.json after a power off
Documentation    ASC | Robustness
...              Verify the recovery from a corrupted agc_data.json when the AMP is powered off and on again (User Guide 10.4). The power off is a step of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-036-1]Corrupt the configuration file
    [Documentation]
    ...              Step 1. Back up /mnt/sc_nonvol/agc_data.json
    ...              Step 2. Overwrite it with something that is not JSON
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-1_corrupt.log    scope=TEST
    ${backup}=    IT COMMON - Run Dut Command And Return    cp /mnt/sc_nonvol/agc_data.json /tmp/agc_data_backup.json
    ${break}=    IT COMMON - Run Dut Command And Return    echo 'this is not json' > /mnt/sc_nonvol/agc_data.json
    ${check}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/agc_data.json
    Log    ${check}
    ${restore}=    IT COMMON - Run Dut Command And Return    cp /tmp/agc_data_backup.json /mnt/sc_nonvol/agc_data.json
    ${after}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/agc_data.json
    Log    ${after}
    Should Not Contain    ${after}    this is not json
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
