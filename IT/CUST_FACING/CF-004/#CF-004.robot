*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Restore the factory default and check what is left in sc_nonvol
Documentation    CUST_FACING | System & Basic Configuration
...              After a factory default only s2p_files and s2pm5d may be left in sc_nonvol, and the system has to be able to complete its init after a reboot (User Guide 10.3). The case wipes the configuration of the DUT, so it is a case that is run on purpose.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-004-1]Restore the factory default and list sc_nonvol
    [Documentation]
    ...              Step 1. Run sc_cli factory_default
    ...              Step 2. List /mnt/sc_nonvol
    ...              Step 3. Only s2p_files and s2pm5d may be left
    ...              Step 4. The reboot that follows is a step of the bench procedure
    [Tags]    CLI    FILE    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_factory_default.log    scope=TEST
    ${default}=    IT COMMON - Run Dut Command And Return    sc_cli factory_default    timeout=120
    Log    ${default}
    ${out}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol
    Log    ${out}
    Should Contain    ${out}    s2p_files
    Should Contain    ${out}    s2pm5d
    Should Not Contain    ${out}    ampapp_data.json
    Should Not Contain    ${out}    rfboard_data.json
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
