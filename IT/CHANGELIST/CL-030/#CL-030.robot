*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The Gen2 PAL API
Documentation    CHANGELIST | CUST_FACING
...              The Gen2 PAL API adds the rf-components and the sc_cli commands of the second generation (CAMP-2338). The parts that this image does not carry yet are checked for the error that they have to report.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-030-1]Read the version and the generation of the amplifier
    [Documentation]
    ...              Step 1. Read the version of the image
    ...              Step 2. Read the generation over gNMI
    ...              Step 3. The generation has to be GEN2
    [Tags]    FILE    GNMI
    VAR    ${sc_log}    ${case_name}-1_generation.log    scope=TEST
    ${version}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt
    Should Contain    ${version}    SW_VERSION=00.04.006
    ${response}=    IT COMMON - Gnmi Get And Return    /amp-generation/version
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    /amp-generation/version
    Log    ${value}
    Should Be Equal    ${value}    GEN2

[CL-030-2]Read the rf-components that the Gen2 API adds
    [Documentation]
    ...              Step 1. GET the whole rf-components container
    ...              Step 2. The answer has to hold the indexed nodes of the Gen2 API
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-2_rf_components.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    /rf-components
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    /rf-components
    Log    ${value}
    IT COMMON - Gnmi Leaf Should Exist    ${value}    north-afe-attenuation-db
    IT COMMON - Gnmi Leaf Should Exist    ${value}    north-afe-equalization-db
    IT COMMON - Gnmi Leaf Should Exist    ${value}    north-us-pa-bias
    IT COMMON - Gnmi Leaf Should Exist    ${value}    south-ds-pa-bias

[CL-030-3]Check the negative case of the north port switch path
    [Documentation]
    ...              Step 1. SET the north port switch path to the legacy upstream value
    ...              Step 2. The SET has to fail
    [Tags]    GNMI    WRITE
    VAR    ${sc_log}    ${case_name}-3_negative.log    scope=TEST
    VAR    @{updates}    /rf-components/north-port-switch-path:::string:::NP_SWITCH_LEGACY_UPSTREAM
    ${set}=    IT COMMON - Gnmi Set And Return    ${updates}
    Log    ${set}
    Should Contain    ${set}    failed
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
