*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: Legacy US calibration and the factory compensation of the eCM offset
Documentation    ALIGNMENT | Legacy US Calibration Error Factory Compensation
...              Set the eCM offset to the default 15, run calib_us_legacy with a 0 dB JXP installed, adjust the JXP tilt and update /mnt/sc_factory/ecm_rfb_offset from the measured RLSP deviation (User Guide 4, 10.5). Skipped: a manual RLSP measurement is required after calibration; the suite cannot wait for it.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
${ALN007_ORIGINAL_OFFSET}    ${NONE}
${ALN007_BASE_OFFSET}    ${NONE}
${ALN007_CALIBRATION_LOG}    ${NONE}
${ALN007_MANUAL_DEVIATION}    ${EMPTY}
*** Test Cases ***
[ALN-007-1]Read the eCM TX power limits
    [Documentation]
    ...              Step 1. Read the minimum and the maximum eCM TX power
    ...              Step 2. Check that the eCM is operational
    ...              
    ...              The limits are the window in which the TX power of the eCM
    ...              counts as valid. The legacy US calibration only runs its eCM
    ...              branch when the TX power of the eCM is inside that window
    ...              (User Guide 4, Step 1 and Step 2).
    ...              
    ...              The upper limit is NOT written here. It is not a constant of
    ...              the software but a nonvol value that the factory sets
    ...              (/alignment/max_ecm_tx_power_v2, 52.75 dBmV on the unit of
    ...              the bench), so the factory value is kept and the window the
    ...              calibration really used is read back from the log of the
    ...              alignment in the next case.
    [Tags]    CLI    MANUAL_RLSP    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-ecm_tx_power.log    scope=TEST
    ${min}=    IT COMMON - Run Dut Command And Return    sc_cli get_min_ecm_tx_power
    ${max}=    IT COMMON - Run Dut Command And Return    sc_cli get_max_ecm_tx_power
    Log    ${min}
    Log    ${max}
    Should Contain    ${min}    get_min_ecm_tx_power success
    Should Contain    ${max}    get_max_ecm_tx_power success
    ${min_v}=    IT COMMON - Get Inline Field    ${min}    value
    ${max_v}=    IT COMMON - Get Inline Field    ${max}    value
    ${min_n}=    Evaluate    float($min_v)    modules=builtins
    ${max_n}=    Evaluate    float($max_v)    modules=builtins
    Log    The window of the eCM TX power is ${min_n} to ${max_n} dBmV
    ${ecm}=    IT COMMON - Wait For Dut Command Contains    sc_amphal_cli get_ecm_status    eCM status = Operational    timeout=600    interval=10
    Log    ${ecm}

[ALN-007-2]Set the eCM offset to the default 15
    [Documentation]
    ...              Step 1. Read /mnt/sc_factory/ecm_rfb_offset and keep the value,
    ...                      the suite puts it back at the end
    ...              Step 2. Set the offset to the default 15
    ...              Step 3. Read it back
    ...              
    ...              The User Guide asks the operator to start from the default
    ...              offset 15 (Note 2 of chapter 4): the eCM reports its power
    ...              about 15 dB too high with the new BCM control table, and the
    ...              offset is what the algorithm subtracts from that report. The
    ...              value in the file is the offset of the unit, it is written by
    ...              the factory or by an earlier run of this procedure, never by
    ...              the software itself: the alignment, the AGC and the ASC only
    ...              read it.
    ...              
    ...              The 15 is also the base of the compensation that the last case
    ...              writes: the User Guide adds the deviation of the measured
    ...              RLSP to it.
    [Tags]    FILE    WRITE    MANUAL_RLSP    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-ecm_offset.log    scope=TEST
    ${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_factory/ecm_rfb_offset
    Log    ${out}
    ${original}=    Evaluate    $out.strip()
    ${original_number}=    Evaluate    float($original)
    ${valid}=    Evaluate    math.isfinite($original_number)    modules=math
    Should Be True    ${valid}    Invalid eCM offset: ${original}
    Set Suite Variable    ${ALN007_ORIGINAL_OFFSET}    ${original}
    Log    The file held ${original}, it is put back at the end of the suite
    ${write}=    IT COMMON - Run Dut Root Command And Return    echo 15 > /mnt/sc_factory/ecm_rfb_offset
    ${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_factory/ecm_rfb_offset
    Log    ${out}
    ${base}=    Evaluate    float($out.strip())
    Set Suite Variable    ${ALN007_BASE_OFFSET}    ${base}
    ${is_default}=    Evaluate    abs($base - 15.0) < 0.001    modules=builtins
    IF    "${is_default}" != "True"
        Fail    The eCM offset was set to 15 but the file holds ${base}
    END

[ALN-007-3]Run the legacy US calibration
    [Documentation]
    ...              Step 1. Enter the alignment view
    ...              Step 2. Run sc_cli calib_us_legacy
    ...              Step 3. Check that the calibration ran the eCM method and
    ...                      not the fallback of the old method
    ...              Step 4. Read the JXP tilt of the RF board
    ...              Step 5. Leave the view
    ...              
    ...              The calibration needs a JXP with 0 dB of attenuation and the
    ...              eCM has to be operational. The CLI waits 20 s for the flag of
    ...              the alignment thread, so the answer of the command is the
    ...              result of the calibration itself.
    ...              
    ...              The tilt of the JXP is set to 0 before the calibration, that
    ...              is the state the User Guide asks for. The calibration writes
    ...              the tilt it computed to the RF board, so without this step a
    ...              second run of the case would start with the tilt of the
    ...              first run and the algorithm would compensate for a JXP
    ...              attenuation that is not there.
    [Tags]    CLI    WRITE    MANUAL_RLSP    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-calib_us_legacy.log    scope=TEST
    Set Suite Variable    ${ALN007_CALIBRATION_LOG}    ${NONE}
    ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt
    Log    The JXP tilt before the calibration is ${before}
    ${zero}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_legacy_up_jxp_tilt 0
    Log    ${zero}
    Should Contain    ${zero}    set_legacy_up_jxp_tilt...success
    ${enter}=    IT COMMON - Fdx Enter View    configure alignment    alignment
    ${cursor}=    IT COMMON - Read Journal Cursor
    ${calib}=    IT COMMON - Run Fdx View Command And Return    alignment    debug sc_cli calib_us_legacy    timeout=300
    Log    ${calib}
    Should Contain    ${calib}    calib_us_legacy success
    Should Contain    ${calib}    by eCM Tx Power
    Should Not Contain    ${calib}    old method
    ${journal}=    IT COMMON - Read Legacy Calibration Journal    ${cursor}
    ${exit}=    IT COMMON - Fdx Exit View    alignment
    ${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt
    Log    ${jxp}
    ${tilt}=    IT COMMON - Get Inline Field    ${jxp}    get_legacy_up_jxp_tilt
    ${tilt_n}=    Evaluate    float($tilt)    modules=builtins
    ${in_range}=    Evaluate    0 <= $tilt_n <= 6    modules=builtins
    IF    "${in_range}" != "True"
        Fail    The legacy upstream JXP tilt is ${tilt_n} dB, the algorithm of the calibration knows 0 to 6 dB
    END
    Log    The legacy upstream JXP tilt is ${tilt_n} dB
    Set Suite Variable    ${ALN007_CALIBRATION_LOG}    ${journal}

[ALN-007-4]Check the US TXPWR of the eCM
    [Documentation]
    ...              Step 1. Read the journal record captured during this suite's legacy calibration
    ...              Step 2. Check that the eCM was operational during the calibration
    ...              Step 3. The TX power of the eCM has to be inside the window
    ...                      of the limits that the calibration used
    ...              
    ...              The User Guide asks for the TX power of the eCM to be inside
    ...              the window of 17.25 to 50 dBmV but it gives no command for it.
    ...              The alignment thread writes the TX power of the eCM and the
    ...              window it used into its log, so the check reads them there.
    ...              The User Guide marks the range with a (Need update).
    ...              
    ...              The window in the log is the one the calibration really used,
    ...              so the check holds whatever the factory wrote into the nonvol
    ...              and not a number of the test case.
    [Tags]    LOG    MANUAL_RLSP    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-ecm_tx_power_window.log    scope=TEST
    ${log}=    Get Variable Value    ${ALN007_CALIBRATION_LOG}    default=${NONE}
    Should Not Be Equal    ${log}    ${NONE}    msg=No journal record from this suite's successful legacy calibration.
    Log    ${log}
    ${cm}=    IT COMMON - Get Inline Field    ${log}    isCmOperational
    Should Be Equal    ${cm}    1    msg=eCM was not operational during legacy calibration: ${cm}
    ${pwr1}=    IT COMMON - Get Inline Field    ${log}    ecmTxPwrF1
    ${pwr2}=    IT COMMON - Get Inline Field    ${log}    ecmTxPwrF2
    ${low}=    IT COMMON - Get Inline Field    ${log}    minEcmTxPower
    ${high}=    IT COMMON - Get Inline Field    ${log}    maxEcmTxPower
    ${pwr1_n}=    Evaluate    float($pwr1)    modules=builtins
    ${pwr2_n}=    Evaluate    float($pwr2)    modules=builtins
    ${low_n}=    Evaluate    float($low)    modules=builtins
    ${high_n}=    Evaluate    float($high)    modules=builtins
    Log    The eCM was operational (${cm}), its US TX power is ${pwr1_n} and ${pwr2_n} dBmV, the window is ${low_n} to ${high_n} dBmV
    ${in_window}=    Evaluate    ($low_n < $pwr1_n < $high_n) and ($low_n < $pwr2_n < $high_n)    modules=builtins
    IF    "${in_window}" != "True"
        Fail    The US TX power of the eCM is ${pwr1_n} / ${pwr2_n} dBmV, the window is ${low_n} to ${high_n} dBmV
    END

[ALN-007-5]Measure the RLSP and compute the deviation
    [Documentation]
    ...              Step 1. Read the RLSP of the south port and the legacy RLSP
    ...              Step 2. The deviation is the target RLSP minus the measured RLSP
    ...              
    ...              The User Guide measures the RLSP at SP_US_TP with a meter
    ...              while the US runs at about 100% of the utilization, that is a
    ...              bench action. The DUT holds the same two numbers, the RLSP of
    ...              the upstream profile of the south port is the target and the
    ...              legacy RLSP is the one that the calibration measured, so the
    ...              deviation of the DUT is shown here as the number the meter
    ...              has to confirm.
    ...              
    ...              The deviation that goes into the file is the one that was
    ...              measured on the bench, it is given with the variable
    ...              ALN007_MANUAL_DEVIATION. The case that writes the file fails
    ...              without it.
    [Tags]    CLI    MANUAL_RLSP    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-rlsp.log    scope=TEST
    ${rlsp}=    IT COMMON - Run Dut Command And Return    sc_cli get_rlsp_all south
    Log    ${rlsp}
    ${target}=    IT COMMON - Get Number After Colon    ${rlsp}    South Port rlsp
    ${measured}=    IT COMMON - Get Number After Colon    ${rlsp}    South Port legacy rlsp
    ${dev}=    Evaluate    round($target - $measured, 3)    modules=builtins
    Log    The target RLSP is ${target} dBmV and the RLSP of the calibration is ${measured} dBmV, the deviation of the DUT is ${dev} dB
    ${manual}=    Get Variable Value    ${ALN007_MANUAL_DEVIATION}    default=${EMPTY}
    IF    "${manual}" != "${EMPTY}"
        ${given}=    Evaluate    float($manual)    modules=builtins
        Log    The deviation that goes into the file is ${given} dB, it comes from the measurement on the bench
    ELSE
        Log    No deviation was measured on the bench, the case that writes the file fails
    END

[ALN-007-6]Write the compensated eCM offset
    [Documentation]
    ...              Step 1. The offset is the default 15 plus the deviation that
    ...                      was measured on the bench, e.g. 8.0 - 8.5 = -0.5 dB
    ...                      gives 14.5
    ...              Step 2. Write the offset and read it back
    ...              
    ...              The deviation comes from the measurement of the RLSP at
    ...              SP_US_TP with the US running at about 100% of the utilization,
    ...              which is a bench action, so the case fails when it is not
    ...              given: --variable ALN007_MANUAL_DEVIATION:<deviation in dB>.
    ...              
    ...              The file is put back to the value it had before the suite in
    ...              the teardown, so that the bench unit keeps the compensation it
    ...              came with.
    [Tags]    FILE    WRITE    MANUAL_RLSP    robot:skip    BENCH
    VAR    ${sc_log}    ${case_name}-ecm_offset_write.log    scope=TEST
    ${manual}=    Get Variable Value    ${ALN007_MANUAL_DEVIATION}    default=${EMPTY}
    IF    "${manual}" == "${EMPTY}"
        Fail    The eCM offset needs the deviation of the RLSP that was measured on the bench. Measure the RLSP at SP_US_TP with the US running at about 100% of the utilization, take the target RLSP minus the measured RLSP, and run the suite with --variable ALN007_MANUAL_DEVIATION:<the deviation in dB>.
    END
    ${base}=    Get Variable Value    ${ALN007_BASE_OFFSET}    default=${NONE}
    ${dev}=    Evaluate    float($manual)    modules=builtins
    ${valid}=    Evaluate    math.isfinite($dev)    modules=math
    Should Be True    ${valid}    Invalid RLSP deviation: ${manual}
    ${new}=    Evaluate    round(float($base) + $dev, 3)    modules=builtins
    ${valid}=    Evaluate    math.isfinite($new)    modules=math
    Should Be True    ${valid}    Invalid eCM offset: ${new}
    Log    The eCM offset goes from ${base} to ${new}, the default ${base} plus the deviation ${dev}
    ${write}=    IT COMMON - Run Dut Root Command And Return    echo ${new} > /mnt/sc_factory/ecm_rfb_offset
    ${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_factory/ecm_rfb_offset
    Log    ${out}
    ${read}=    Evaluate    float($out.strip())
    ${same}=    Evaluate    abs($read - $new) < 0.001    modules=builtins
    IF    "${same}" != "True"
        Fail    The eCM offset was written as ${new}, the file holds ${read}
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
    ${original}=    Get Variable Value    ${ALN007_ORIGINAL_OFFSET}    default=${NONE}
    IF    "${original}" != "${NONE}"
        Run Keyword And Continue On Failure    IT COMMON - Restore eCM Factory Offset    ${original}
    END
    # SSH Close can only put in Suite Teardown
    SSH_IT.Close
    SSH_IT_ROOT.Close
    GNMI_IT.Close
    log to console  \n\t=== Suite Teardown STOP ===
