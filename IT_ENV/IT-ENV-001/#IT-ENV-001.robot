*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-19
# @comment: Check that the bench is ready before the campaign starts
Documentation    IT | Environment check
...              The checks that tell whether the bench can carry the campaign. They run before the first test item, because a bench that is not ready shows up as a failure in the middle of a campaign, where it costs the most time. Every check is a test case of its own, so the report says which one failed.
Resource    ../__init_resource.robot
Resource    ../../resource/Common/IT_Env.resource
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
*** Test Cases ***
[IT-ENV-001-1]The firmware images are in the local directory
    [Documentation]
    ...              Step 1. Look for the two images of the campaign in the
    ...                      local image directory
    ...              Step 2. Both of them have to be there
    [Tags]    ENV    LOCAL
    VAR    ${sc_log}    ${case_name}-1_images.log    scope=TEST
    ${files}=    IT ENV - The Firmware Images Are In The Local Directory
    Log    ${files}

[IT-ENV-001-2]The firmware images are on the firmware server
    [Documentation]
    ...              Step 1. Put the images of the campaign on the firmware
    ...                      server, with a PUT to the URL the DUT asks for
    ...              Step 2. The DUT has to find them there, with the same
    ...                      request the AMP makes itself
    [Tags]    ENV    WRITE
    VAR    ${sc_log}    ${case_name}-2_upload.log    scope=TEST
    IT ENV - The Firmware Images Are Uploaded To The Server
    IT ENV - The Firmware Images Are On The Server

[IT-ENV-001-3]The DUT is the unit of the campaign
    [Documentation]
    ...              Step 1. Read the serial number of the DUT
    ...              Step 2. It has to be the one of the variable file
    [Tags]    ENV    GNMI
    VAR    ${sc_log}    ${case_name}-3_serial.log    scope=TEST
    IT ENV - The Dut Is The Expected Unit

[IT-ENV-001-4]The DUT reports its firmware version
    [Documentation]
    ...              Step 1. Read the version of the DUT
    ...              Step 2. The campaign says which image it ran against
    [Tags]    ENV    CLI
    VAR    ${sc_log}    ${case_name}-4_version.log    scope=TEST
    ${version}=    IT ENV - The Dut Reports Its Firmware Version
    Log    ${version}

[IT-ENV-001-5]The DUT reaches the firmware server
    [Documentation]
    ...              Step 1. Ping the firmware server from the DUT
    ...              Step 2. The DUT pulls the image over the management port,
    ...                      so it has to reach the server from there
    [Tags]    ENV    CLI
    VAR    ${sc_log}    ${case_name}-5_network.log    scope=TEST
    IT ENV - The Dut Sees The Firmware Server
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
