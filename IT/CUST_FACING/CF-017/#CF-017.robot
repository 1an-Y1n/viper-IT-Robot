*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-18
# @comment: The mandatory set and get commands of the Sercomm RF board CLI
Documentation    CUST_FACING | Sercomm CLI
...              Verify the mandatory set and get commands of sc_rfboard_cli (User Guide 3.6). Every set is validated with its get command.
Resource    ../__init_resource.robot
# Global Variables
Suite Setup    Suite Initialization
Suite Teardown   Suite Teardown

*** Variables ***
${case_name}    ${SUITE NAME.rsplit('#')[-1]}
# the suite carries no variable of its own
*** Test Cases ***
[CF-017-1]Set and read the attenuation
    [Documentation]
    ...              Step 1. Read the attenuation of the first entry
    ...              Step 2. Set it and read it back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-1_attenuation.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
    ${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_attenuation 2 8.0
    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0
    Log    ${after}
    Should Contain    ${after}    SP_DS_ATT

[CF-017-2]Set and read the variable tilt
    [Documentation]
    ...              Step 1. Read the tilt of the second entry
    ...              Step 2. Set it and read it back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-2_tilt.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0
    ${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 2 11.7
    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0
    Log    ${after}
    Should Contain    ${after}    SP_DS_1.2G_VEQ

[CF-017-3]Set and read the PA current
    [Documentation]
    ...              Step 1. Read the PA current
    ...              Step 2. Set it and read it back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-3_pa_current.log    scope=TEST
    ${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_pa_current 0
    ${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_pa_current 1 498.5
    ${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_pa_current 0
    Log    ${after}
    Should Contain    ${after}    DS_HYBRID_PA_BIAS
    Should Contain    ${after}    US_FINAL_PA_BIAS

[CF-017-4]Read the JXP tilt and the two calibration flags
    [Documentation]
    ...              Step 1. Read the JXP tilt of the RF board
    ...              Step 2. Read the two calibration flags
    ...              Step 3. Set the NP monitor input and read it back
    [Tags]    CLI    WRITE
    VAR    ${sc_log}    ${case_name}-4_flags.log    scope=TEST
    ${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt
    Log    ${jxp}
    Should Contain    ${jxp}    get_legacy_up_jxp_tilt =
    ${ignore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj
    Log    ${ignore}
    Should Contain    ${ignore}    get_ignore_np_ds_calib_adj =
    ${auto}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_auto_adj_legacy_vatt
    Log    ${auto}
    Should Contain    ${auto}    get_auto_adj_legacy_vatt =
    ${monitor}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_np_monitor_input us
    ${input}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_np_monitor_input
    Log    ${input}
    ${back}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_np_monitor_input ds
    ${restored}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_np_monitor_input
    Log    ${restored}
    Should Contain    ${restored}    downstream
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
