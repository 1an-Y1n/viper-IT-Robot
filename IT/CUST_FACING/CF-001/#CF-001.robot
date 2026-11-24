*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Run the sanity check script of the DUT
Documentation    CUST_FACING | Sanity Check
...              Run the sanity check script that ships with the firmware and check that every check passes (User Guide 10.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-001-1]Run the sanity check script
    [Documentation]
    ...              Step 1. Run /usr/bin/amp-gnmi-check.sh
    ...              Step 2. Check that every check of the script passed
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-1_sanity.log    scope=TEST
    ${idle}=    IT COMMON - Wait For No Gnmi Instance With    amp-alignment[alignment-type=*]    alignment-status    ALIGN_STATUS_IN_PROGRESS    timeout=300
    ${out}=    IT COMMON - Run Dut Command And Return    /usr/bin/amp-gnmi-check.sh    timeout=600
    Log    ${out}
    Should Not Be Equal    ${out}    ${EMPTY}
    ${failed}=    Evaluate    [line for line in $out.splitlines() if '[FAIL]' in line]    modules=builtins
    IF    $failed
        Fail    The sanity check of the DUT reports failed checks: ${failed}
    END
    Should Contain    ${out}    Failed: 0
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
