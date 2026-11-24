*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Check the login and the prompts of the three shells
Documentation    CUST_FACING | System & Basic Configuration
...              Check that the tester can log in with the default account and that the expected prompts are seen (User Guide 1.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-002-1]Check the clish prompt
    [Documentation]
    ...              Step 1. Run a command on the clish shell
    ...              Step 2. The buffer has to carry the clish prompt
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_clish_prompt.log    scope=TEST
    ${buffer}=    IT COMMON - Run Fdx Command And Return Raw    show version
    Should Contain    ${buffer}    FDX-AMP>$

[CF-002-2]Check the linux shell prompt
    [Documentation]
    ...              Step 1. Run a command on the linux shell
    ...              Step 2. The buffer has to carry the linux prompt
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_linux_prompt.log    scope=TEST
    ${buffer}=    IT COMMON - Run Dut Command And Return Raw    uname -a
    Should Contain    ${buffer}    bash-3.2#

[CF-002-3]Check the Broadcom HAL prompt
    [Documentation]
    ...              Step 1. Enter the HAL from the clish shell
    ...              Step 2. The buffer has to carry the HAL prompt
    ...              Step 3. Leave the HAL again
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-3_hal_prompt.log    scope=TEST
    ${buffer}=    IT COMMON - Run Fdx Command And Return Buffer    debug hal    timeout=15    prompt=hal>
    Log    ${buffer}
    Should Contain    ${buffer}    Connected.
    Should Contain    ${buffer}    hal>
    ${out}=    IT COMMON - Run Fdx Command And Return Raw    \x04    prompt=FDX-AMP>$
    Should Contain    ${out}    FDX-AMP>$

[CF-002-4]Check the three Broadcom CLI wrappers
    [Documentation]
    ...              Step 1. Check that the three sockets of the Broadcom CLI wrappers are there
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-4_cliwrapper.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    ls -l /tmp/brcmsystem.sock /tmp/brcmhal.sock /tmp/brcmupgrade.sock
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
