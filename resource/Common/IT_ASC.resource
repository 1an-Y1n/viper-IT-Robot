*** Settings ***
Resource    IT_Common.resource

*** Keywords ***
IT ASC - NP DS Should Be Idle
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    ${enabled}=    IT COMMON - Get Cli Field    ${status}    enabled
    ${stage}=    IT COMMON - Get Cli Field    ${status}    current_stage
    Should Be Equal    ${enabled}    true
    Should Be Equal    ${stage}    Idle

IT ASC - NP DS Should Be Running
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds
    ${enabled}=    IT COMMON - Get Cli Field    ${status}    enabled
    ${stage}=    IT COMMON - Get Cli Field    ${status}    current_stage
    Should Be Equal    ${enabled}    true
    Should Not Be Equal    ${stage}    Idle    msg=NP DS has not started a round.
    RETURN    ${status}

IT ASC - ADU State Should Be
    [Arguments]    ${expected}
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_adu_status
    ${actual}=    IT COMMON - Get Inline Field    ${status}    name
    Should Be Equal    ${actual}    ${expected}

IT ASC - All FSMs Should Have State
    [Arguments]    ${expected_enabled}    ${idle}=${FALSE}
    FOR    ${fsm}    IN    np_ds    sp_ds    np_us    clipping
        ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status ${fsm}
        ${enabled}=    IT COMMON - Get Cli Field    ${status}    enabled
        Should Be Equal    ${enabled}    ${expected_enabled}    msg=${fsm} enabled state differs
        IF    $idle
            ${stage}=    IT COMMON - Get Cli Field    ${status}    current_stage
            Should Be Equal    ${stage}    Idle    msg=${fsm} has not stopped
        END
    END

IT ASC - FSM Status Should Be Valid
    [Arguments]    ${fsm}    ${name}    ${expected_enabled}
    ${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status ${fsm}
    ${actual_name}=    IT COMMON - Get Cli Field    ${status}    fsm
    ${enabled}=    IT COMMON - Get Cli Field    ${status}    enabled
    ${count}=    IT COMMON - Get Cli Field    ${status}    loop_count
    ${stage}=    IT COMMON - Get Cli Field    ${status}    current_stage
    ${next}=    IT COMMON - Get Cli Field    ${status}    next_stage
    ${running}=    IT COMMON - Get Cli Field    ${status}    running_status
    Should Be Equal    ${actual_name}    ${name}
    Should Be Equal    ${enabled}    ${expected_enabled}
    Should Match Regexp    ${count}    ^[0-9]+$
    Should Not Be Empty    ${stage}
    Should Not Be Empty    ${next}
    Should Be True    $running in ('Idle', 'Done', 'ContinueDelay', 'Wait', 'Error')    msg=Unknown FSM running status: ${running}
    RETURN    ${status}

IT ASC - Get DUT Boot ID
    ${out}=    IT COMMON - Run Dut Root Command And Return    cat /proc/sys/kernel/random/boot_id
    ${boot_id}=    Evaluate    $out.strip()
    Should Match Regexp    ${boot_id}    ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$
    RETURN    ${boot_id}

IT ASC - Confirm DUT Reboot
    [Arguments]    ${before}
    IT COMMON - Wait For Dut To Come Back    timeout=20    interval=5
    ${after}=    IT ASC - Get DUT Boot ID
    Should Not Be Equal    ${after}    ${before}    msg=The DUT has not rebooted yet.

IT ASC - Service Should Be Active
    ${status}=    IT COMMON - Run Dut Command And Return    systemctl is-active sc-asc
    ${status}=    Evaluate    $status.strip()
    Should Be Equal    ${status}    active

IT ASC - Telemetry Interval Should Equal
    [Arguments]    ${expected}
    ${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    IT COMMON - Cli Number Should Equal    ${agc}    Telemetry persist interval    ${expected}
    ${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/agc_data.json    timeout=5    poll=1
    ${private}=    IT COMMON - Get Dict Field    ${parsed}    private_config
    ${saved}=    IT COMMON - Get Dict Field    ${private}    telemetry_persist_interval
    Should Be Equal As Integers    ${saved}    ${expected}

IT ASC - Grpc And CLI Configuration Should Equal
    [Arguments]    ${expected}
    ${response}=    IT COMMON - Grpcurl And Return Json    asc_config.proto    gnoi.asc_config.v1.AscConfigService/GetAscConfiguration
    IT COMMON - Grpc Should Succeed    ${response}
    ${config}=    IT COMMON - Grpc Get Field    ${response}    ascConfig
    ${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    VAR    @{fields}    inputInterval    outputInterval    clippingInterval    inputPowerTransientThreshold    deltaPilotDiffThreshold    maxPositiveAdjustment    maxNegativeAdjustment    firstPilotFrequency    secondPilotFrequency    thirdPilotFrequency
    ${enable}=    Get From Dictionary    ${expected}    enable
    ${actual_enable}=    IT COMMON - Grpc Get Field    ${config}    enable
    Should Be Equal As Integers    ${actual_enable}    ${enable}
    VAR    &{modes}    0=Disable    1=FreeRun    2=Monitor
    ${enable_key}=    Convert To String    ${enable}
    ${mode}=    Get From Dictionary    ${modes}    ${enable_key}
    IT COMMON - Cli Field Should Equal    ${cli}    operationMode    ${mode}
    FOR    ${field}    IN    @{fields}
        ${value}=    Get From Dictionary    ${expected}    ${field}
        ${actual}=    IT COMMON - Grpc Get Field    ${config}    ${field}
        Should Be Equal As Numbers    ${actual}    ${value}    msg=gRPC ${field} differs
        IT COMMON - Cli Number Should Equal    ${cli}    ${field}    ${value}
    END

IT ASC - Persisted Configuration Should Equal
    [Arguments]    ${mode}    ${interval}    ${power_threshold}    ${att_threshold}    ${eq_threshold}    ${notify_interval}
    ${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/agc_data.json    timeout=5    poll=1
    ${public}=    IT COMMON - Get Dict Field    ${parsed}    public_config
    ${private}=    IT COMMON - Get Dict Field    ${parsed}    private_config
    ${saved_mode}=    IT COMMON - Get Dict Field    ${public}    operation_mode
    ${saved_interval}=    IT COMMON - Get Dict Field    ${public}    input_interval
    ${saved_power}=    IT COMMON - Get Dict Field    ${public}    input_power_transient_threshold
    ${saved_att}=    IT COMMON - Get Dict Field    ${private}    fdx_us_att_threshold
    ${saved_eq}=    IT COMMON - Get Dict Field    ${private}    fdx_us_eq_threshold
    ${saved_notify}=    IT COMMON - Get Dict Field    ${private}    rfboard_notify_interval
    VAR    &{modes}    Disable=0    FreeRun=1    Monitor=2
    ${mode_number}=    Get From Dictionary    ${modes}    ${mode}
    Should Be Equal As Integers    ${saved_mode}    ${mode_number}
    Should Be Equal As Integers    ${saved_interval}    ${interval}
    Should Be Equal As Numbers    ${saved_power}    ${power_threshold}
    Should Be Equal As Numbers    ${saved_att}    ${att_threshold}
    Should Be Equal As Numbers    ${saved_eq}    ${eq_threshold}
    Should Be Equal As Integers    ${saved_notify}    ${notify_interval}

IT ASC - Live Configuration Should Equal
    [Arguments]    ${mode}    ${interval}    ${power_threshold}    ${att_threshold}    ${eq_threshold}    ${notify_interval}
    ${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    ${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    IT COMMON - Cli Field Should Equal    ${asc}    operationMode    ${mode}
    IT COMMON - Cli Number Should Equal    ${asc}    inputInterval    ${interval}
    IT COMMON - Cli Number Should Equal    ${asc}    inputPowerTransientThreshold    ${power_threshold}
    IT COMMON - Cli Number Should Equal    ${agc}    pathloss change ATT Threshold    ${att_threshold}
    IT COMMON - Cli Number Should Equal    ${agc}    pathloss change EQ Threshold    ${eq_threshold}
    IT COMMON - Cli Number Should Equal    ${agc}    Rfboard notify interval    ${notify_interval}

IT ASC - Set And Verify Persisted Configuration
    [Arguments]    ${mode}    ${interval}    ${power_threshold}    ${att_threshold}    ${eq_threshold}    ${notify_interval}
    VAR    &{modes}    Disable=0    FreeRun=1    Monitor=2
    ${mode_number}=    Get From Dictionary    ${modes}    ${mode}
    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval ${interval}
    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputPowerTransientThreshold ${power_threshold}
    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode ${mode_number}
    ${set_agc}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 1 ${att_threshold}
    Run Keyword And Continue On Failure    Should Contain    ${set_agc}    set_agc_config...success
    ${set_eq}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 2 ${eq_threshold}
    Run Keyword And Continue On Failure    Should Contain    ${set_eq}    set_agc_config...success
    ${set_notify}=    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 11 ${notify_interval}
    Run Keyword And Continue On Failure    Should Contain    ${set_notify}    set_agc_config...success
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Live Configuration Should Equal    ${mode}    ${interval}    ${power_threshold}    ${att_threshold}    ${eq_threshold}    ${notify_interval}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    120s    5s    IT ASC - Persisted Configuration Should Equal    ${mode}    ${interval}    ${power_threshold}    ${att_threshold}    ${eq_threshold}    ${notify_interval}

IT ASC - Restore ASC Configuration
    [Arguments]    ${mode}    ${interval}    ${threshold}    ${pilot}
    VAR    &{modes}    Disable=0    FreeRun=1    Monitor=2
    ${mode_number}=    Get From Dictionary    ${modes}    ${mode}
    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval ${interval}
    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputPowerTransientThreshold ${threshold}
    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config thirdPilotFrequency ${pilot}
    Run Keyword And Continue On Failure    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode ${mode_number}
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    Run Keyword And Continue On Failure    IT COMMON - Cli Field Should Equal    ${after}    operationMode    ${mode}
    Run Keyword And Continue On Failure    IT COMMON - Cli Number Should Equal    ${after}    inputInterval    ${interval}
    Run Keyword And Continue On Failure    IT COMMON - Cli Number Should Equal    ${after}    inputPowerTransientThreshold    ${threshold}
    Run Keyword And Continue On Failure    IT COMMON - Cli Number Should Equal    ${after}    thirdPilotFrequency    ${pilot}

IT ASC - Restore Operation Mode
    [Arguments]    ${mode}
    VAR    &{modes}    Disable=0    FreeRun=1    Monitor=2
    ${number}=    Get From Dictionary    ${modes}    ${mode}
    ${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode ${number}
    ${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config
    IT COMMON - Cli Field Should Equal    ${after}    operationMode    ${mode}
