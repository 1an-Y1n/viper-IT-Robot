*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The WBFFT capture and the hardware installation over gRPC
Documentation    CUST_FACING | GRPC Tests
...              The template holds two content blocks under this id: the WBFFT capture over gRPC and the three steps of the hardware installation. Both of them are two test cases of this suite.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${wbfft_proto}    wbfft_capture.proto
${hw_proto}    hw_installation.proto
*** Test Cases ***
[CF-054-1]Run the WBFFT capture over gRPC
    [Documentation]
    ...              Step 1. Call GetWbfftCapture with the capture configuration
    ...              Step 2. The answer has to hold the results of the capture
    [Tags]    GRPC
    VAR    ${sc_log}    ${case_name}-1_wbfft.log    scope=TEST
    VAR    ${payload}    {"wbfft_capture_configuration": {"start_frequency_hz": 0, "end_frequency_hz": 1218000000, "fft_size": 16384, "sampling_rate_hz": 1647000000, "output_format": "OutputFormat_FreqDomainPower", "windowing_mode": "WindowingMode_None", "averaging_mode": "AveragingMode_Time", "output_scale": 6, "aggregation_period_ms": 200, "sample_point": "SamplePoint_NpD", "reset_averaging_between_measurements": false, "measurement_count": 0, "measurement_rate_ms": 1, "total_measurement_duration_ms": 200}}
    ${response}=    IT COMMON - Grpcurl And Return Json    ${wbfft_proto}    gnoi.wbfft.v1.WbfftCapture/GetWbfftCapture    ${payload}    timeout=120
    Log    ${response}

[CF-054-2]Read the pre-alignment status over gRPC
    [Documentation]
    ...              Step 1. Call GetPreAlignmentStatus
    ...              Step 2. The answer has to hold the eCM registration and the input power
    ...              Step 3. Compare the input power with the north port status
    [Tags]    GRPC    CLI
    VAR    ${sc_log}    ${case_name}-2_pre_alignment.log    scope=TEST
    ${response}=    IT COMMON - Grpcurl And Return Json    ${hw_proto}    gnoi.hw_installation.v1.HwInstallation/GetPreAlignmentStatus
    IT COMMON - Grpc Should Succeed    ${response}
    ${registration}=    IT COMMON - Grpc Get Field    ${response}    ecmRegistration
    Should Be True    ${registration}
    ${tcp}=    IT COMMON - Grpc Get Field    ${response}    northPortInputTcp
    Log    ${tcp}
    ${pab}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status
    Log    ${pab}
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_port_status 0
    ${input}=    IT COMMON - Get Cli Field    ${status}    rx_adc_input_power_dbmv_tcp
    Log    ${input}

[CF-054-3]Set the initial configuration over gRPC
    [Documentation]
    ...              Step 1. Call SetInitialConfiguration
    ...              Step 2. The answer has to report success
    [Tags]    GRPC    WRITE
    VAR    ${sc_log}    ${case_name}-3_initial_configuration.log    scope=TEST
    VAR    ${payload}    {"spectrum": {"downstream_begin_hz": 108000000, "downstream_end_hz": 1218000000, "legacy_upstream_begin_hz": 5000000, "legacy_upstream_end_hz": 85000000, "extended_upstream_begin_hz": 108000000, "extended_upstream_end_hz": 684000000, "description": "Default_Genesis_DDD_1.2GHz_Test_by_User", "subband_modes": [3, 3, 3]}, "downstream_profile": [{"port_type": 1, "description": "North port downstream profile", "start_frequency_hz": 120000000, "end_frequency_hz": 1002000000, "start_downstream_psd_dbmv_per_6mhz": 36.8, "end_downstream_psd_dbmv_per_6mhz": 45.0}, {"port_type": 2, "description": "South port downstream profile", "start_frequency_hz": 120000000, "end_frequency_hz": 1002000000, "start_downstream_psd_dbmv_per_6mhz": 36.8, "end_downstream_psd_dbmv_per_6mhz": 45.0}], "upstream_profile": [{"port_type": 1, "target_receive_power_dbmv_per_6_4_mhz": 6.0}, {"port_type": 2, "target_receive_power_dbmv_per_6_4_mhz": 6.0}], "north_port_afe_backoff": 3.0, "north_port_target_tcp": 35.0, "north_port_is_threshold": 4.0}
    ${response}=    IT COMMON - Grpcurl And Return Json    ${hw_proto}    gnoi.hw_installation.v1.HwInstallation/SetInitialConfiguration    ${payload}
    IT COMMON - Grpc Should Succeed    ${response}

[CF-054-4]Start the calibration over gRPC
    [Documentation]
    ...              Step 1. Call StartCalibration
    ...              Step 2. The stream has to report the progress of the stages
    [Tags]    GRPC    WRITE
    VAR    ${sc_log}    ${case_name}-4_start_calibration.log    scope=TEST
    ${documents}=    IT COMMON - Grpcurl And Return Json List    ${hw_proto}    gnoi.hw_installation.v1.HwInstallation/StartCalibration    ${EMPTY}    timeout=600
    Log    ${documents}
    ${stages}=    Evaluate    [d['progress']['status'] for d in $documents if isinstance(d, dict) and 'progress' in d]    modules=builtins
    Log    The reported stages are ${stages}
    Should Not Be Empty    ${stages}
    ${failures}=    Evaluate    [d['failure'] for d in $documents if isinstance(d, dict) and 'failure' in d]    modules=builtins
    IF    $failures
        Fail    The calibration failed: ${failures}
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
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
