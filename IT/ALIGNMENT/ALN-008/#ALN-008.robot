*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The auto, semi-auto and manual modes of the clish calibration
Documentation    ALIGNMENT | CLISH Calibration Modes
...              Verify the CLISH calibration sub-modes (auto, semi-auto <stage>, manual <stage>), show calibration-status and the sequential stage dependency rule (User Guide 10.13).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ALN-008-1]Run the calibration in auto mode
    [Documentation]
    ...              Step 1. Enter the calibration view
    ...              Step 2. Start the calibration in auto mode
    ...              Step 3. Check that the four stages ran, in order, and that the
    ...                      calibration finished with SUCCESS
    ...              Step 4. Leave the view
    ...              
    ...              The command prints one progress line per stage and the result
    ...              of the calibration at the end. The auto mode runs every stage
    ...              of the lineup in order: DS1, DS2, DS3 and US1. Measured on the
    ...              bench: about two minutes.
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-auto.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration
    ${start}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration auto    timeout=600
    Log    ${start}
    Should Contain    ${start}    Progress: STAGE_DS1
    Should Contain    ${start}    Progress: STAGE_DS2
    Should Contain    ${start}    Progress: STAGE_DS3
    Should Contain    ${start}    Progress: STAGE_US1
    ${order}=    IT COMMON - Progress Line Order    ${start}    DS1    DS2    DS3    US1
    Log    The stages ran at ${order}
    IT COMMON - Check Calibration Result    ${start}    0
    ${exit}=    IT COMMON - Fdx Exit View    calibration

[ALN-008-2]Run the calibration in semi-auto mode from the DS1 stage
    [Documentation]
    ...              Step 1. Enter the calibration view
    ...              Step 2. Start the calibration in semi-auto mode from ds1
    ...              Step 3. Check that it ran through the remaining stages on its
    ...                      own and finished with SUCCESS
    ...              Step 4. Leave the view
    ...              
    ...              The semi-auto mode starts at the stage that is given and then
    ...              goes on by itself through the remaining stages. Measured on the
    ...              bench: about two minutes, the same as the auto mode.
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-semi_auto.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration
    ${start}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration semi-auto ds1    timeout=600
    Log    ${start}
    Should Contain    ${start}    Progress: STAGE_DS1
    Should Contain    ${start}    Progress: STAGE_DS2
    Should Contain    ${start}    Progress: STAGE_DS3
    Should Contain    ${start}    Progress: STAGE_US1
    ${order}=    IT COMMON - Progress Line Order    ${start}    DS1    DS2    DS3    US1
    Log    The stages ran at ${order}
    IT COMMON - Check Calibration Result    ${start}    0
    ${exit}=    IT COMMON - Fdx Exit View    calibration

[ALN-008-3]Run every stage on its own in manual mode
    [Documentation]
    ...              Step 1. Enter the calibration view
    ...              Step 2. Start the calibration in manual mode from ds1, from ds2,
    ...                      from ds3 and from us1, one after the other
    ...              Step 3. Check that every one of them ran only its own stage and
    ...                      finished with SUCCESS
    ...              Step 4. Leave the view
    ...              
    ...              The manual mode runs the stage that is given and nothing else,
    ...              that is the difference to the semi-auto mode.
    ...              
    ...              The stages have to be run one after the other in this order.
    ...              Measured on the bench: a stage that is not the first one is
    ...              given up on when the stage before it was not run in the manual
    ...              mode right before it, the calibration service answers
    ...              'Alignment failed for stage: N' (US1=0, DS1=1, DS2=2, DS3=3) and
    ...              the alignment log shows that the stage was aborted before it
    ...              produced a result. That is the sequential stage dependency rule
    ...              of the User Guide (10.13.2 and 10.13.3).
    [Tags]    CLI    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-manual.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration
    ${ds1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds1    timeout=600
    Log    ${ds1}
    Should Contain    ${ds1}    Progress: STAGE_DS1
    Should Not Contain    ${ds1}    Progress: STAGE_DS2
    Should Not Contain    ${ds1}    Progress: STAGE_DS3
    Should Not Contain    ${ds1}    Progress: STAGE_US1
    IT COMMON - Check Calibration Result    ${ds1}    1
    ${ds2}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds2    timeout=600
    Log    ${ds2}
    Should Contain    ${ds2}    Progress: STAGE_DS2
    Should Not Contain    ${ds2}    Progress: STAGE_DS1
    Should Not Contain    ${ds2}    Progress: STAGE_DS3
    Should Not Contain    ${ds2}    Progress: STAGE_US1
    IT COMMON - Check Calibration Result    ${ds2}    2
    ${ds3}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual ds3    timeout=600
    Log    ${ds3}
    Should Contain    ${ds3}    Progress: STAGE_DS3
    Should Not Contain    ${ds3}    Progress: STAGE_DS1
    Should Not Contain    ${ds3}    Progress: STAGE_DS2
    Should Not Contain    ${ds3}    Progress: STAGE_US1
    IT COMMON - Check Calibration Result    ${ds3}    3
    ${us1}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration manual us1    timeout=600
    Log    ${us1}
    Should Contain    ${us1}    Progress: STAGE_US1
    Should Not Contain    ${us1}    Progress: STAGE_DS1
    Should Not Contain    ${us1}    Progress: STAGE_DS2
    Should Not Contain    ${us1}    Progress: STAGE_DS3
    IT COMMON - Check Calibration Result    ${us1}    0
    ${exit}=    IT COMMON - Fdx Exit View    calibration

[ALN-008-4]Check the calibration status
    [Documentation]
    ...              Step 1. Enter the calibration view
    ...              Step 2. Show the calibration status
    ...              Step 3. Check that the four stages are ALIGNED and that no
    ...                      calibration is running
    ...              Step 4. Leave the view
    ...              
    ...              The status is the gRPC GetCalibrationStatus of the calibration
    ...              service: one line per stage with the state of the stage, and
    ...              the flag that says whether a calibration is running.
    [Tags]    CLI    BENCH
    VAR    ${sc_log}    ${case_name}-status.log    scope=TEST
    ${enter}=    IT COMMON - Fdx Enter View    configure calibration    calibration
    ${status}=    IT COMMON - Run Fdx View Command And Return    calibration    show calibration-status
    ${exit}=    IT COMMON - Fdx Exit View    calibration
    Log    ${status}
    Should Contain    ${status}    Stage: STAGE_DS1, Status: ALIGNED
    Should Contain    ${status}    Stage: STAGE_DS2, Status: ALIGNED
    Should Contain    ${status}    Stage: STAGE_DS3, Status: ALIGNED
    Should Contain    ${status}    Stage: STAGE_US1, Status: ALIGNED
    ${running}=    IT COMMON - Get Text After Label    ${status}    Calibrating
    Should Be Equal    ${running}    false
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
