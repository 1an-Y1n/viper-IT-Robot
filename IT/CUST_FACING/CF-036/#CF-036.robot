*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Read and set the amp-identification over gNMI
Documentation    CUST_FACING | GNMI Tests
...              Retrieve the amp-identification and set its nine fields over gNMI (User Guide 9.11).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${path}    amp-identification
*** Test Cases ***
[CF-036-1]GET the amp-identification
    [Documentation]
    ...              Step 1. GET amp-identification
    ...              Step 2. The answer has to hold the identity of the device
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-1_get.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    amp-identification
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    amp-identification
    Log    ${value}
    ${serial}=    IT COMMON - Get Dict Field    ${value}    serial-number
    Should Be Equal    ${serial}    ${DUT_IT_SERIAL}
    ${vendor}=    IT COMMON - Get Dict Field    ${value}    vendor-name
    Should Be Equal    ${vendor}    SERCOMM
    ${mac}=    IT COMMON - Get Dict Field    ${value}    device-mac-address
    Log    ${mac}

[CF-036-2]SET the nine fields of the amp-identification
    [Documentation]
    ...              Step 1. SET the description and the geo position
    ...              Step 2. GET the answer back and check the nine fields
    [Tags]    GNMI    WRITE
    VAR    ${sc_log}    ${case_name}-2_set.log    scope=TEST
    VAR    @{updates}    /amp-identification/device-location/description:::string:::Location    /amp-identification/device-location/geo/latitude/direction:::string:::NORTH    /amp-identification/device-location/geo/latitude/degrees:::uint:::37    /amp-identification/device-location/geo/latitude/minutes:::uint:::47    /amp-identification/device-location/geo/latitude/seconds:::uint:::30    /amp-identification/device-location/geo/longitude/direction:::string:::WEST    /amp-identification/device-location/geo/longitude/degrees:::uint:::122    /amp-identification/device-location/geo/longitude/minutes:::uint:::25    /amp-identification/device-location/geo/longitude/seconds:::uint:::10
    ${set}=    IT COMMON - Gnmi Set And Return    ${updates}
    Log    ${set}
    Should Contain    ${set}    UPDATE
    ${response}=    IT COMMON - Gnmi Get And Return    amp-identification
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    amp-identification
    ${location}=    IT COMMON - Get Dict Field    ${value}    device-location
    ${description}=    IT COMMON - Get Dict Field    ${location}    description
    Should Be Equal    ${description}    Location
    ${geo}=    IT COMMON - Get Dict Field    ${location}    geo
    ${latitude}=    IT COMMON - Get Dict Field    ${geo}    latitude
    ${degrees}=    IT COMMON - Get Dict Field    ${latitude}    degrees
    Should Be Equal As Integers    ${degrees}    37
    ${longitude}=    IT COMMON - Get Dict Field    ${geo}    longitude
    ${west}=    IT COMMON - Get Dict Field    ${longitude}    direction
    Should Be Equal    ${west}    WEST
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
