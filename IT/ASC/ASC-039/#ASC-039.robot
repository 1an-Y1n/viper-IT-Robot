*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The AGC with the FDX enablement workaround
Documentation    ASC | AGC with FDX Enablement (Workaround)
...              Verify the User Guide 8.6 workaround for the AGC test with the FDX enablement: disable the ASC, do the FDX enablement, trigger the AGC baseline store with calib_us_legacy, reboot and enable the ASC again (User Guide 8.6). The FDX enablement and the reboot are steps of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-039-1]Disable the ASC
    [Documentation]
    ...              Step 1. Set the operation mode to Disable
    ...              Step 2. Read the ASC configuration
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_disable.log    scope=TEST
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Log    ${config}
    Should Contain    ${config}    operationMode = Disable

[ASC-039-2]Trigger the AGC baseline store
    [Documentation]
    ...              Step 1. Run sc_cli calib_us_legacy
    ...              Step 2. Check that the calibration succeeded
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_baseline.log    scope=TEST
    ${calib}=    IT COMMON - Run Dut Command Until Not Refused    sc_cli calib_us_legacy    Failed to request ALN control from MSC    timeout=600    interval=15    cmd_timeout=120
    Log    ${calib}
    Should Contain    ${calib}    success

[ASC-039-3]Enable the ASC again
    [Documentation]
    ...              Step 1. Set the operation mode to FreeRun
    ...              Step 2. Read the ASC configuration
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-3_enable.log    scope=TEST
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1
    ${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Log    ${config}
    Should Contain    ${config}    operationMode = FreeRun
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
