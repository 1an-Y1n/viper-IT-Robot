*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Set the SP DS 1.2G VEQ over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Modify the SP_DS_1.2G_VEQ rf-component with gNMI and read the value back (User Guide 9.2.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-045-1]SET the SP DS 1.2G VEQ over gNMI
    [Documentation]
    ...              Step 1. GET the equalization of the downstream output
    ...              Step 2. SET the non-volatile and the volatile value
    ...              Step 3. GET them again and compare with sc_rfboard_cli
    [Tags]    GNMI    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_set.log    scope=TEST
    VAR    @{updates}    /rf-components/ds-output-eq-db[index=0]/equalization-db:::float:::19.0    /rf-components/ds-output-eq-volatile-db[index=0]/equalization-db:::float:::11.0
    VAR    @{paths}    /rf-components/ds-output-eq-db[index=0]/equalization-db    /rf-components/ds-output-eq-volatile-db[index=0]/equalization-db
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
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 2
    Log    ${cli}
    Should Contain    ${cli}    SP_DS_1.2G_VEQ
    ${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json
    Should Contain    ${json}    sp_ds_1p2g_veq_tilt_db
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
