*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The SSH login to the embedded cable modem
Documentation    CUST_FACING | SSH (Ch14)
...              Verify the standard operating procedure to log in to the embedded cable modem from the eAMP (User Guide 14.7).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-060-1]Check that the embedded cable modem answers
    [Documentation]
    ...              Step 1. Read the registration status of the modem
    ...              Step 2. The modem has to be operational
    ...              Step 3. Check that the modem answers on its management address
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_ecm.log    scope=TEST
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_snmp_cm_status
    Log    ${status}
    Should Contain    ${status}    eCM is OPERATIONAL
    ${ping}=    IT COMMON - Run Dut Command And Return    ping -c 2 -W 3 172.31.255.45    timeout=30
    Log    ${ping}
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
