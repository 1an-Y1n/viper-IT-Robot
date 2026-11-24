*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The DS Tracker configuration and its monitor data
Documentation    CUST_FACING | DS Tracker (Ch13)
...              Verify the DS Tracker configuration, its process, its gNMI monitor data and the periodic syslog (User Guide 13). The upgrade of the binary needs a server and is a step of the bench procedure.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${proto}    ds_periodic_maintanence.proto
${method}    gnoi.ds_periodic_maintanence.v1.DownstreamPeriodicMaintanence/SetDpmConfiguration
${get_method}    gnoi.ds_periodic_maintanence.v1.DownstreamPeriodicMaintanence/GetDpmConfiguration
*** Test Cases ***
[CF-056-1]Set the DS Tracker configuration over gRPC
    [Documentation]
    ...              Step 1. Call SetDpmConfiguration
    ...              Step 2. The answer has to report success
    ...              Step 3. GET the configuration again
    [Tags]    GRPC    WRITE
    VAR    ${sc_log}    ${case_name}-1_set.log    scope=TEST
    VAR    ${payload}    {"enabled": true, "configuration": {"period_in_seconds": 3600, "number_of_wbfft_captures": 200, "number_of_aggregation": 60, "startup_delay_seconds": 0}, "wbfft_capture_configuration": {"description": "Sample FFT config", "start_frequency_hz": 108000000, "end_frequency_hz": 1218000000, "fft_size": 16384, "sampling_rate_hz": 1647000000, "output_format": "OutputFormat_FreqDomainPower", "windowing_mode": "WindowingMode_None", "averaging_mode": "AveragingMode_Time", "output_scale": 6, "aggregation_period_ms": 200, "sample_point": "SamplePoint_NpD", "reset_averaging_between_measurements": false, "measurement_count": 0, "measurement_rate_ms": 1, "total_measurement_duration_ms": 200}, "adjustment_threshold_range": [{"min_value": 188946946, "max_value": 381364161}]}
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}
    IT COMMON - Grpc Should Succeed    ${response}
    ${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
    IT COMMON - Grpc Should Succeed    ${after}
    ${enabled}=    IT COMMON - Grpc Get Field    ${after}    enabled
    Should Be True    ${enabled}

[CF-056-2]Read the monitor data of the DS Tracker over gNMI
    [Documentation]
    ...              Step 1. GET ds-monitor-data
    ...              Step 2. The answer has to hold the state of the tracker
    [Tags]    GNMI
    VAR    ${sc_log}    ${case_name}-2_monitor.log    scope=TEST
    ${response}=    IT COMMON - Gnmi Get And Return    ds-monitor-data
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ds-monitor-data
    Log    ${value}

[CF-056-3]Check the process of the DS Tracker and its syslog
    [Documentation]
    ...              Step 1. Look for the tracker process
    ...              Step 2. Look for the periodic telemetry in the syslog
    [Tags]    FILE
    VAR    ${sc_log}    ${case_name}-3_process.log    scope=TEST
    ${process}=    IT COMMON - Run Dut Command And Return    ps aux | grep -i track
    Log    ${process}
    ${syslog}=    IT COMMON - Run Dut Command And Return    cat /dev/shm/syslog | grep -i 'cached DS telemetry'
    Log    ${syslog}
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
