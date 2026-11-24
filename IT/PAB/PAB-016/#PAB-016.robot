*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Check that PAB runs in FreeRun mode after a factory default and a reboot
Documentation    PAB | FreeRun Boot-up
...              After the factory default configuration is restored and the DUT is rebooted, PAB has to start automatically in FREERUN mode and keep running until the eCM comes online (User Guide 6.2, 10.3).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[PAB-016-1]Check that PAB is in FreeRun mode after the bring up
    [Documentation]
    ...              Step 1. The DUT has been restored to the factory default and rebooted
    ...              Step 2. GET the PAB status
    ...              Step 3. Check that PAB is enabled and runs in FreeRun mode
    ...              Step 4. Check that the eCM is operational
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_sc_cli.log    scope=TEST
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    ${enabled}=    IT COMMON - Get Cli Field    ${status}    Enabled
    Should Be Equal    ${enabled}    Yes
    ${mode}=    IT COMMON - Get Cli Field    ${status}    Running Mode
    Should Be Equal    ${mode}    FREERUN
    ${ecm_status}=    IT COMMON - Wait For Dut Command Contains
    ...    sc_amphal_cli get_ecm_status
    ...    eCM status = Operational
    ...    timeout=180    interval=10
    Log    ${ecm_status}

[PAB-016-2]Check the PAB configuration after the bring up
    [Documentation]
    ...              Step 1. GET the PAB configuration
    ...              Step 2. Check that the configuration is the factory default: the LNA
    ...                      mode is FIXED_GAIN, the gain is 2.74 dBmV, the target TCP is
    ...                      36.00 dBmV, the intervals are 60 sec and the thresholds are
    ...                      -27.78 dBmV and 6.00
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_sc_cli.log    scope=TEST
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config
    ${mode}=    IT COMMON - Get Cli Field    ${config}    rx adc lna mode
    Should Be Equal    ${mode}    3 (FIXED_GAIN)
    ${gain}=    IT COMMON - Get Cli Field    ${config}    rx adc lna gain
    Should Be Equal    ${gain}    2.74 dBmV
    ${tcp}=    IT COMMON - Get Cli Field    ${config}    target tcp
    Should Be Equal    ${tcp}    36.00 dBmV
    ${online}=    IT COMMON - Get Cli Field    ${config}    online interval
    Should Be Equal    ${online}    60 sec
    ${retry}=    IT COMMON - Get Cli Field    ${config}    retry interval
    Should Be Equal    ${retry}    60 sec
    ${rpd}=    IT COMMON - Get Cli Field    ${config}    RPD power threshold
    Should Be Equal    ${rpd}    -27.78 dBmV
    ${outlier}=    IT COMMON - Get Cli Field    ${config}    outlier threshold
    Should Be Equal    ${outlier}    6.00
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
