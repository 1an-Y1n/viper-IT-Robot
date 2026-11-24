*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The gRPC calibration service in its auto, semi-auto and manual modes
Documentation    ALIGNMENT | GRPC Calibration Service
...              Verify the gRPC calibration service in AUTO, SEMI_AUTO and MANUAL modes plus GetCalibrationStatus; StartCalibration is a streaming RPC that reports the progress of every stage (User Guide 12.1.2).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    calibration.proto
${start_method}    gnoi.calibration.v1.Calibration/StartCalibration
${status_method}    gnoi.calibration.v1.Calibration/GetCalibrationStatus
${ALN014_CALIBRATION_BLOCKED}    ${FALSE}
*** Test Cases ***
[ALN-014-1]Start the calibration in auto mode over gRPC
    [Documentation]
    ...              Step 1. Call StartCalibration with mode AUTO
    ...              Step 2. Check ordered stage progress and final SUCCESS
    [Tags]    GRPC    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_auto.log    scope=TEST
    VAR    ${payload}    {"mode": "AUTO"}
    VAR    ${ALN014_CALIBRATION_BLOCKED}    ${TRUE}    scope=SUITE
    ${response}=    IT COMMON - Grpcurl And Return Json List    ${proto}    ${start_method}    ${payload}    timeout=600
    GrpcJson.Check Calibration Stream    ${response}    AUTO
    VAR    ${ALN014_CALIBRATION_BLOCKED}    ${FALSE}    scope=SUITE

[ALN-014-2]Start the calibration in semi-auto mode over gRPC
    [Documentation]
    ...              Step 1. Call StartCalibration with mode SEMI_AUTO and startStage STAGE_DS1
    ...              Step 2. Check ordered progress and SUCCESS or a manual adjustment stop
    [Tags]    GRPC    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-2_semi_auto.log    scope=TEST
    VAR    ${payload}    {"mode": "SEMI_AUTO", "startStage": "STAGE_DS1"}
    IF    $ALN014_CALIBRATION_BLOCKED    Skip    Previous calibration did not complete successfully; inspect its result before starting another.
    VAR    ${ALN014_CALIBRATION_BLOCKED}    ${TRUE}    scope=SUITE
    ${response}=    IT COMMON - Grpcurl And Return Json List    ${proto}    ${start_method}    ${payload}    timeout=600
    ${outcome}=    GrpcJson.Check Calibration Stream    ${response}    SEMI_AUTO
    Log    Semi-auto outcome: ${outcome}
    IF    $outcome == 'SUCCESS'
        VAR    ${ALN014_CALIBRATION_BLOCKED}    ${FALSE}    scope=SUITE
    END

[ALN-014-3]Start the calibration in manual mode over gRPC
    [Documentation]
    ...              Step 1. Call StartCalibration with mode MANUAL and startStage STAGE_DS1
    ...              Step 2. Check DS1 is the only stage and the stream ends in SUCCESS
    [Tags]    GRPC    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-3_manual.log    scope=TEST
    VAR    ${payload}    {"mode": "MANUAL", "startStage": "STAGE_DS1"}
    IF    $ALN014_CALIBRATION_BLOCKED    Skip    Previous calibration failed or requires manual adjustment; inspect its result before starting another.
    ${response}=    IT COMMON - Grpcurl And Return Json List    ${proto}    ${start_method}    ${payload}    timeout=600
    GrpcJson.Check Calibration Stream    ${response}    MANUAL

[ALN-014-4]Read the calibration status over gRPC
    [Documentation]
    ...              Step 1. Call GetCalibrationStatus
    ...              Step 2. Check the stage statuses and any manual adjustments
    [Tags]    GRPC    BENCH
    VAR    ${sc_log}    ${case_name}-4_status.log    scope=TEST
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${status_method}
    GrpcJson.Check Calibration Status    ${response}
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
