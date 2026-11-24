*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The telnet client is gone from the eAMP
Documentation    CHANGELIST | CUST_FACING
...              The telnet customization is removed from the eAMP, so the embedded cable modem can only be reached over SSH (CAMP-2415).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CL-002-1]Check that the telnet client is gone
    [Documentation]
    ...              Step 1. Check that which telnet does not find anything
    ...              Step 2. Check that /usr/bin/telnet and /bin/telnet are not there
    ...              Step 3. Check that the telnet applet is not in the BusyBox list
    ...              Step 4. Check that busybox telnet reports that the applet is not there
    [Tags]    CLI    FILE
    VAR    ${sc_log}    ${case_name}-1_telnet.log    scope=TEST
    ${which}=    IT COMMON - Run Dut Command And Return    which telnet
    Log    ${which}
    Should Not Contain    ${which}    /bin/telnet
    Should Not Contain    ${which}    /usr/bin/telnet
    ${usr_bin}=    IT COMMON - Run Dut Command And Return    ls -l /usr/bin/telnet
    Log    ${usr_bin}
    Should Contain    ${usr_bin}    No such file
    ${bin}=    IT COMMON - Run Dut Command And Return    ls -l /bin/telnet
    Log    ${bin}
    Should Contain    ${bin}    No such file
    ${applet}=    IT COMMON - Run Dut Command And Return    busybox 2>&1 | grep telnet
    Log    ${applet}
    Should Be Equal    ${applet}    ${EMPTY}
    ${run}=    IT COMMON - Run Dut Command And Return    busybox telnet 172.31.255.45
    Log    ${run}
    Should Contain    ${run}    applet not found

[CL-002-2]Check the private link to the embedded cable modem
    [Documentation]
    ...              Step 1. Check the route to the private link
    ...              Step 2. Ping the embedded cable modem
    ...              Step 3. Read the status of the embedded cable modem
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_link.log    scope=TEST
    ${route}=    IT COMMON - Run Dut Command And Return    ip route | grep 172.31.255
    Log    ${route}
    Should Contain    ${route}    172.31.255.0/24
    ${ping}=    IT COMMON - Run Dut Command And Return    ping -c 2 -W 3 172.31.255.45    timeout=30
    Log    ${ping}
    ${status}=    IT COMMON - Run Dut Command And Return    sc_amphal_cli get_ecm_status
    Log    ${status}
    Should Contain    ${status}    eCM status = Operational
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
