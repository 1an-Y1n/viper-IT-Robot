*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Check that the configuration files were migrated
Documentation    CUST_FACING | System & Basic Configuration
...              After a firmware update the configuration file has to be updated according to the latest default configuration (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-003-1]Compare the RF board configuration with its default
    [Documentation]
    ...              Step 1. Read /mnt/sc_nonvol/rfboard_data.json
    ...              Step 2. Read /mnt/sc_nonvol/rfboard_data.json.default
    ...              Step 3. Both have to carry the same version
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-1_rfboard_data.log    scope=TEST
    ${current_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/rfboard_data.json
    ${default_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/rfboard_data.json.default
    ${current_version}=    Evaluate    $current_json.get('version')    modules=builtins
    ${default_version}=    Evaluate    $default_json.get('version')    modules=builtins
    Should Be Equal    ${current_version}    ${default_version}

[CF-003-2]Compare the AMP application configuration with its default
    [Documentation]
    ...              Step 1. Read /mnt/sc_nonvol/ampapp_data.json
    ...              Step 2. Read the default of the AMP application configuration
    ...              Step 3. Both have to carry the same version
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-2_ampapp_data.log    scope=TEST
    ${current_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json
    ${current_version}=    Evaluate    $current_json.get('version')    modules=builtins
    ${out}=    IT COMMON - Run Dut Command And Return    ls -l /card0/amp/ampapp_data.json.default
    Log    ${out}
    Should Not Contain    ${out}    No such file
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
