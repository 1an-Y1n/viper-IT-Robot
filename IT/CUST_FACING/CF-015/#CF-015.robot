*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Check that the configuration survives a reboot
Documentation    CUST_FACING | Comcast CLI
...              After a reboot every configuration has to stay the same. The reboot is a step of the bench procedure, so the case compares the configuration with the one that was read before the reboot.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-015-1]Read the configuration before and after the reboot
    [Documentation]
    ...              Step 1. Read the configuration of the AMP application
    ...              Step 2. The DUT has been rebooted in the meantime
    ...              Step 3. Read the configuration again and compare the two
    [Tags]    FILE    BENCH
    VAR    ${sc_log}    ${case_name}-1_reboot.log    scope=TEST
    ${before_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json
    ${before_version}=    Evaluate    $before_json.get('version')    modules=builtins
    ${after_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json
    ${after_version}=    Evaluate    $after_json.get('version')    modules=builtins
    Should Be Equal    ${after_version}    ${before_version}
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
