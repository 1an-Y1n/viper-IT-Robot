*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set the US FDX output VCEQ over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Modify the US_FDX_OUT_VCEQ rf-component with gNMI and read the value back (User Guide 9.2.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-048-1]SET the US FDX output VCEQ over gNMI
    [Documentation]
    ...              Step 1. GET the US FDX equalization
    ...              Step 2. SET the value
    ...              Step 3. GET it again and compare with sc_rfboard_cli
    [Tags]    GNMI    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_set.log    scope=TEST
    VAR    @{updates}    /rf-components/us-fdx-equalization-db:::float:::9.5
    VAR    @{paths}    /rf-components/us-fdx-equalization-db
    FOR    ${path}    IN    @{paths}
        ${before}=    IT COMMON - Gnmi Get And Return    ${path}
    END
    ${set}=    IT COMMON - Gnmi Set And Return    ${updates}
    Log    ${set}
    Should Contain    ${set}    UPDATE
    FOR    ${path}    IN    @{paths}
        ${after}=    IT COMMON - Gnmi Get And Return    ${path}
        ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    ${path}
        Log    ${value}
    END
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 3
    Log    ${cli}
    Should Contain    ${cli}    US_FDX_OUT_VCEQ
    ${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json
    Should Contain    ${json}    us_fdx_out_vceq_tilt_db
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
