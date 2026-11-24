*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Check that the syslog backup appears after the boot
Documentation    CUST_FACING | System & Basic Configuration
...              Three minutes after the boot the syslog_backup.tar.1.gz has to appear in sc_nonvol (User Guide 10.4). The reboot is a step of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-006-1]Check that the syslog backup is there
    [Documentation]
    ...              Step 1. Three minutes after the reboot the backup has to be there
    [Tags]    FILE    BENCH
    VAR    ${sc_log}    ${case_name}-1_syslog_backup.log    scope=TEST
    ${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/syslog_backup.tar.1.gz    timeout=300    interval=15
    Should Not Be Equal    ${size}    0
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
