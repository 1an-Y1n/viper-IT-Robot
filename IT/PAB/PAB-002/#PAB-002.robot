*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read the whole PAB result container over gNMI
Documentation    PAB | GNMI Result (Container & Stage 1~7)
...              Read the whole PAB result container over gNMI and check that it holds the payload of every stage, stage 1 to stage 7 (User Guide 9.16.1).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${path}    pab-result
@{stages}    stage-1    stage-2    stage-3    stage-4    stage-5    stage-6    stage-7
*** Test Cases ***
[PAB-002-1]GET the whole PAB result container over gNMI
    [Documentation]
    ...              Step 1. GET pab-result
    ...              Step 2. Check that the container holds the seven stages
    ...              Step 3. Check that every stage holds its own leaves
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_gnmi.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    ${path}
    ${container}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}
    FOR    ${stage}    IN    @{stages}
        IT COMMON - Gnmi Leaf Should Exist    ${container}    ${stage}
    END

[PAB-002-2]Check the leaves of every stage of the container
    [Documentation]
    ...              Step 1. GET pab-result
    ...              Step 2. Walk the seven stages and check their leaves
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-2_gnmi.log    scope=TEST
    VAR    &{stage_leaves}    stage-1=["message", "np-ds-att-after-lna", "np-ds-att-before-lna", "np-ds-att-between-lna", "np-ds-inverse-eq", "np-ds-vceq", "rx-adc-lna-gain-db", "status", "us-fdx-in-att", "us-fdx-out-att", "us-legacy-att-after-lna", "us-legacy-att-before-lna"]    stage-2=["fdx-clip-count", "fdx-stable-cnt", "message", "nafe-clip-count", "nafe-stable-cnt", "np-ds-att-after-lna", "np-ds-att-before-lna", "np-ds-att-between-lna", "status"]    stage-3=["message", "np-ds-att-before-lna", "np-ds-att-between-lna", "np-f-tcp", "status"]    stage-4=["message", "np-afe-tcp", "np-ds-att-after-lna", "np-ds-att-between-lna", "run-iteration", "status", "target-tcp"]    stage-5=["first-lna-output-tcp", "message", "np-afe-tcp", "np-ds-att-after-lna", "np-ds-att-before-lna", "np-ds-att-between-lna", "np-ds-inverse-eq", "np-ds-vceq", "real-np-input-tcp", "run-iteration", "second-lna-output-tcp", "status", "target-tcp"]    stage-6=["fdx-clip-count", "fdx-stable-cnt", "message", "nafe-clip-count", "nafe-stable-cnt", "np-ds-att-after-lna", "np-ds-att-before-lna", "np-ds-att-between-lna", "status"]    stage-7=["ecm-online", "message", "status"]
    ${response}=    IT COMMON - Gnmi Get And Return    ${path}
    ${container}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}
    FOR    ${stage}    IN    @{stages}
        ${leaves}=    IT COMMON - Gnmi Stage Leaves Should Exist    ${container}    ${stage}    ${stage_leaves}[${stage}]
    END
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
