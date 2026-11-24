*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The secondary commands of the Sercomm RF board CLI
Documentation    CUST_FACING | Sercomm CLI
...              Exercise the secondary sc_rfboard_cli commands (the board control, the RF frequency, the raw PA current / attenuation / tilt, the NP DS adjustment, the EEPROM read, the RF board temperature, the AGC and FDX US ignore flags and the calibration reset) (User Guide 3.6, 10.8).
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-018-1]Read the state of the RF board and its frequency
    [Documentation]
    ...              Step 1. Read the state of the RF board
    ...              Step 2. Read the RF frequency
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-1_board.log    scope=TEST
    ${state}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli board_state
    ${freq}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_rf_frequency
    Log    ${state}
    Log    ${freq}
    Should Contain    ${state}    RF board state: ACTIVE
    Should Contain    ${freq}    RF frequency mode is set to

[CF-018-2]Read the temperature of the RF board
    [Documentation]
    ...              Step 1. Read the temperature of the local sensor and of the three channels
    [Tags]    CLI
    VAR    ${sc_log}    ${case_name}-2_temperature.log    scope=TEST
    ${temp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_rfboard_temperature all
    Log    ${temp}
    Should Contain    ${temp}    CHANNEL LOCAL
    Should Contain    ${temp}    CHANNEL 1
    Should Contain    ${temp}    CHANNEL 2
    Should Contain    ${temp}    CHANNEL 3

[CF-018-3]Read the EEPROM partition table and dump a partition
    [Documentation]
    ...              Step 1. Read the partition table
    ...              Step 2. Read the first partition into a file
    ...              Step 3. Check that the file is there
    [Tags]    CLI    FILE    WRITE
    VAR    ${sc_log}    ${case_name}-3_eeprom.log    scope=TEST
    ${table}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli eeprom_get_partition_tale
    Log    ${table}
    Should Contain    ${table}    RFB_DATA
    ${read}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli eeprom_partition_read 1 /tmp/eeprom_p1.bin    timeout=60
    Log    ${read}
    ${size}=    IT COMMON - Wait For File On Dut    /tmp/eeprom_p1.bin    timeout=60
    Should Not Be Equal    ${size}    0

[CF-018-4]Set and read the AGC and the FDX US ignore flags
    [Documentation]
    ...              Step 1. Set the two flags and read them back
    ...              Step 2. Put them back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-4_flags.log    scope=TEST
    ${restore_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_restore_agc_adj 1
    ${restore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_restore_agc_adj
    Should Contain    ${restore}    get_ignore_restore_agc_adj = 1
    ${reset_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_reset_fdx_us 1
    ${reset}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_reset_fdx_us
    Should Contain    ${reset}    get_ignore_reset_fdx_us = 1
    ${restore_back}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_restore_agc_adj 0
    ${reset_back}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_reset_fdx_us 0

[CF-018-5]Run the NP DS attenuation adjustment
    [Documentation]
    ...              Step 1. Run the adjustment
    ...              Step 2. Read the result of the adjustment
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-5_adjust.log    scope=TEST
    ${adjust}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli adjust_np_ds_atts 1.5 35 0    timeout=60
    Log    ${adjust}
    ${result}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli adjust_np_ds_atts_result
    Log    ${result}
    Should Contain    ${result}    NP_DS_ATT_BEFORE_LNA
    Should Contain    ${result}    NP_DS_ATT_AFTER_LNA
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
