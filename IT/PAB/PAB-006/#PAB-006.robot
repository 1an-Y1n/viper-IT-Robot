*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read the stage-4 result of the PAB procedure over gNMI
Documentation    PAB | GNMI Result (Container & Stage 1~7)
...              Read the results of PAB stage 4 over gNMI and check that the information of the stage is complete (User Guide 9.16.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${path}    pab-result/stage-4
*** Test Cases ***
[PAB-006-1]GET the stage-4 result over gNMI
    [Documentation]
    ...              Step 1. GET pab-result/stage-4
    ...              Step 2. Check that every leaf of the stage is present
    ...              Step 3. Check that the stage reports OK
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_gnmi.log    scope=TEST
    VAR    @{leaves}    message    np-afe-tcp    np-ds-att-after-lna    np-ds-att-between-lna    run-iteration    status    target-tcp
    ${response}=    IT COMMON - Gnmi Get And Return    ${path}
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}
    ${names}=    IT COMMON - Gnmi Leaf Names Of    ${value}
    IT COMMON - Gnmi Leaves Should Exist    ${names}    ${leaves}
    ${status}=    IT COMMON - Get Dict Field    ${value}    status
    Should Be Equal    ${status}    OK
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
