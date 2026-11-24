*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Check that the calibration snapshot is stored and readable
Documentation    ASC | Config/Target Data save
...              Verify that the calibration snapshot is saved and readable (User Guide 10.4).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[ASC-008-1]Check that the calibration snapshot is stored
    [Documentation]
    ...              Step 1. Run a full automatic calibration
    ...              Step 2. Compare the stored snapshot and show output
    ...              Step 3. Reboot and repeat the comparison, checking the snapshot is unchanged
    [Tags]    CLI    FILE    WRITE    BENCH
    VAR    ${sc_log}    ${case_name}-1_snapshot.log    scope=TEST
    VAR    @{tcp_fields}    calib_npf_tcp    calib_npd_tcp    calib_ds_spf_tcp    target_soc_in_tcp
    VAR    @{state_fields}    np_ds_att_after_lna_attenuation_db    np_ds_att_before_lna_attenuation_db    np_ds_att_between_lnas_attenuation_db    np_ds_inverse_eq_tilt_db    np_ds_vceq_tilt_db    sp_ds_1p2g_veq_tilt_db    sp_ds_1p8g_veq_tilt_db    sp_ds_att_attenuation_db    us_fdx_in_att_attenuation_db    us_fdx_out_att_attenuation_db    us_fdx_out_vceq_tilt_db    us_legacy_att_after_lna_attenuation_db    us_legacy_att_before_lna_attenuation_db
    VAR    @{bin_fields}    pilot_wbfft    np_ds_reference_dsis    sp_ds_target_spectrum    np_f_reference_spectrum    fdx_path_gain_cal
    IT COMMON - Fdx Enter View    configure calibration    calibration
    TRY
        ${start}=    IT COMMON - Run Fdx View Command And Return    calibration    start-calibration auto    timeout=600
        IT COMMON - Progress Line Order    ${start}    DS1    DS2    DS3    US1
        IT COMMON - Check Calibration Result    ${start}    0
    FINALLY
        IT COMMON - Fdx Exit View    calibration
    END
    ${snapshot_file}=    Set Variable    /mnt/sc_nonvol/asc_calib_snapshot.json
    ${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/asc_calib_snapshot.json    timeout=60
    Should Not Be Equal    ${size}    0
    ${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    ${end_freq}=    IT COMMON - Get Cli Field    ${show}    ds_end_frequency_hz
    Should Be True    int($end_freq.split()[0]) > 0    msg=No calibration snapshot was saved
    ${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${fdx_enabled}=    IT COMMON - Get Cli Field    ${agc}    Fdx enable
    Should Be True    $fdx_enabled in ('true', 'false')    msg=Invalid FDX enable state
    ${summary}=    IT COMMON - Run Dut Root Command And Return    jq -Mce 'select([.pilot_wbfft,.np_ds_reference_dsis,.sp_ds_target_spectrum,.np_f_reference_spectrum,.fdx_path_gain_cal] | all(type == "array")) | {calib_npf_tcp,calib_npd_tcp,calib_ds_spf_tcp,target_soc_in_tcp,calibration_state,pilot_goertzel,counts:{pilot_wbfft:(.pilot_wbfft|length),np_ds_reference_dsis:(.np_ds_reference_dsis|length),sp_ds_target_spectrum:(.sp_ds_target_spectrum|length),np_f_reference_spectrum:(.np_f_reference_spectrum|length),fdx_path_gain_cal:(.fdx_path_gain_cal|length)}}' ${snapshot_file}    timeout=120
    ${parsed}=    Evaluate    json.loads($summary)    modules=json
    FOR    ${field}    IN    @{tcp_fields}
        ${actual}=    IT COMMON - Get Cli Field    ${show}    ${field}
        ${expected}=    Get From Dictionary    ${parsed}    ${field}
        Should Be True    abs(float($actual.split()[0]) - float($expected)) <= 0.01    msg=Snapshot TCP ${field} differs from show
    END
    ${state}=    Get From Dictionary    ${parsed}    calibration_state
    FOR    ${field}    IN    @{state_fields}
        ${actual}=    IT COMMON - Get Text After Label    ${show}    ${field}
        ${expected}=    Get From Dictionary    ${state}    ${field}
        Should Be True    abs(float($actual.split()[0]) - float($expected)) <= 0.01    msg=Snapshot RF state ${field} differs from show
    END
    ${pilots}=    Get From Dictionary    ${parsed}    pilot_goertzel
    ${pilot_count}=    IT COMMON - Get Cli Field    ${show}    pilot_goertzel
    Should Be Equal As Integers    ${pilot_count.split()[0]}    ${{len($pilots)}}
    Should Not Be Empty    ${pilots}
    FOR    ${pilot}    IN    @{pilots}
        ${freq}=    Get From Dictionary    ${pilot}    freq
        ${value}=    Get From Dictionary    ${pilot}    value
        ${actual}=    IT COMMON - Get Text After Label    ${show}    ${freq} Hz
        Should Be True    abs(float($actual.split()[0]) - float($value)) <= 0.01    msg=Snapshot pilot ${freq} differs from show
    END
    ${counts}=    Get From Dictionary    ${parsed}    counts
    FOR    ${field}    IN    @{bin_fields}
        ${actual}=    IT COMMON - Get Cli Field    ${show}    ${field}
        ${count}=    Get From Dictionary    ${counts}    ${field}
        IF    $field != 'fdx_path_gain_cal' or $fdx_enabled == 'true'
            Should Be True    int($count) > 0    msg=Snapshot ${field} is empty
        END
        Should Be Equal As Integers    ${actual.split()[0]}    ${count}    msg=Snapshot bin count ${field} differs from show
    END
    ${before_hash}=    IT COMMON - Run Dut Root Command And Return    sha256sum ${snapshot_file}
    Should Match Regexp    ${before_hash.strip()}    ^[0-9a-f]{64}\\s
    ${boot_id}=    IT ASC - Get DUT Boot ID
    Run Keyword And Ignore Error    IT COMMON - Run Fdx Command And Return    reset
    Wait Until Keyword Succeeds    900s    10s    IT ASC - Confirm DUT Reboot    ${boot_id}
    ${after_hash}=    IT COMMON - Run Dut Root Command And Return    sha256sum ${snapshot_file}
    Should Be Equal    ${after_hash.strip()}    ${before_hash.strip()}    msg=Snapshot file changed across reboot
    ${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show
    ${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config
    ${fdx_enabled}=    IT COMMON - Get Cli Field    ${agc}    Fdx enable
    Should Be True    $fdx_enabled in ('true', 'false')    msg=Invalid FDX enable state
    ${summary}=    IT COMMON - Run Dut Root Command And Return    jq -Mce 'select([.pilot_wbfft,.np_ds_reference_dsis,.sp_ds_target_spectrum,.np_f_reference_spectrum,.fdx_path_gain_cal] | all(type == "array")) | {calib_npf_tcp,calib_npd_tcp,calib_ds_spf_tcp,target_soc_in_tcp,calibration_state,pilot_goertzel,counts:{pilot_wbfft:(.pilot_wbfft|length),np_ds_reference_dsis:(.np_ds_reference_dsis|length),sp_ds_target_spectrum:(.sp_ds_target_spectrum|length),np_f_reference_spectrum:(.np_f_reference_spectrum|length),fdx_path_gain_cal:(.fdx_path_gain_cal|length)}}' ${snapshot_file}    timeout=120
    ${parsed}=    Evaluate    json.loads($summary)    modules=json
    FOR    ${field}    IN    @{tcp_fields}
        ${actual}=    IT COMMON - Get Cli Field    ${show}    ${field}
        ${expected}=    Get From Dictionary    ${parsed}    ${field}
        Should Be True    abs(float($actual.split()[0]) - float($expected)) <= 0.01    msg=Snapshot TCP ${field} differs from show
    END
    ${state}=    Get From Dictionary    ${parsed}    calibration_state
    FOR    ${field}    IN    @{state_fields}
        ${actual}=    IT COMMON - Get Text After Label    ${show}    ${field}
        ${expected}=    Get From Dictionary    ${state}    ${field}
        Should Be True    abs(float($actual.split()[0]) - float($expected)) <= 0.01    msg=Snapshot RF state ${field} differs from show
    END
    ${pilots}=    Get From Dictionary    ${parsed}    pilot_goertzel
    ${pilot_count}=    IT COMMON - Get Cli Field    ${show}    pilot_goertzel
    Should Be Equal As Integers    ${pilot_count.split()[0]}    ${{len($pilots)}}
    Should Not Be Empty    ${pilots}
    FOR    ${pilot}    IN    @{pilots}
        ${freq}=    Get From Dictionary    ${pilot}    freq
        ${value}=    Get From Dictionary    ${pilot}    value
        ${actual}=    IT COMMON - Get Text After Label    ${show}    ${freq} Hz
        Should Be True    abs(float($actual.split()[0]) - float($value)) <= 0.01    msg=Snapshot pilot ${freq} differs from show
    END
    ${counts}=    Get From Dictionary    ${parsed}    counts
    FOR    ${field}    IN    @{bin_fields}
        ${actual}=    IT COMMON - Get Cli Field    ${show}    ${field}
        ${count}=    Get From Dictionary    ${counts}    ${field}
        IF    $field != 'fdx_path_gain_cal' or $fdx_enabled == 'true'
            Should Be True    int($count) > 0    msg=Snapshot ${field} is empty
        END
        Should Be Equal As Integers    ${actual.split()[0]}    ${count}    msg=Snapshot bin count ${field} differs from show
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
    # the suite has nothing to clean up
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
