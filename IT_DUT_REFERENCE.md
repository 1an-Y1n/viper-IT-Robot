# DUT reference for the IT suites

Everything below was read off the bench DUT
(`172.21.48.226`, serial `SCMLSC25240006`, firmware `00.04.006ER3`) with the
`viper-tether` skill. It is the ground truth for the expected output of the
assertions, so a suite can be written without guessing the wording of a CLI.

The DUT is the eAMP linux shell. `sc_cli` is a dispatcher: the PAB and the ASC
commands live in `sc_alignment_cli` and in the ASC module, but `sc_cli` routes
to them, so `sc_cli get_pab_config` and `sc_cli get_asc_config` both work.

## The command families

```
sc_cli             the general command set (calibration, attenuation, AGC, ASC, PAB, ...)
sc_alignment_cli   pab_enable, pab_control, get_pab_status, set_pab_config, get_pab_config, manual_pab
sc_rfboard_cli     the RF board: attenuations, tilts, PA bias, board control, EEPROM
sc_amphal_cli      the HAL: get_ecm_status, get_np_config, get_sp_config, get_np_status, get_sp_status, get_np_mon_status
sc_msc_cli         the master control: MSC state, controller, statistics, MGC timeout
sc_log_cli         the logging: -z <zone> -l <level>
```

`gnmic`, `grpcurl`, `amp-gnmi-check.sh` and `amp-ident.sh` are on the DUT as
well.

## sc_cli

### ALN-015 calibration controls on .233

On UNIFIED_LE `172.21.48.233`, firmware `00.04.006`, the four RF board
calibration flags and the `sc_cli` station mode and interference ratio
commands are available. `sc_rfboard_cli` does not list the template's
`set_single_mode_gain_delta` or `get_single_mode_gain_delta`; both are
available under `sc_cli` instead. CLI floating-point reads print six decimal
places, so restoring the printed value can lose calibration precision. The
live nonvol service can be read at full double precision with
`libsc_nonvol_get_number` from `/usr/lib/libsc_cfg.so.1`. Its file persistence
is debounced; read the live value before changing it, not just the file.
Changing and reading the gain delta does not prove its effect on RLSP accuracy.

### PAB

```
$ sc_cli get_pab_config
PAB Configuration:
  rx adc lna mode      : 2 (FREE_RUNNING)
  rx adc lna gain      : 2.74 dBmV
  target tcp           : 36.00 dBmV
  online interval      : 60 sec
  retry interval       : 60 sec
  RPD power threshold  : -21.78 dBmV
  outlier threshold    : 6.00

$ sc_cli get_pab_status
PAB Status:
  Enabled         : Yes
  Completed       : Yes
  Loop count      : 1
  eCM online      : Yes
  Running Mode    : FREERUN
  Running Status  : DONE
  Current Stage   : IDLE

$ sc_cli pab_control stop
Success: PAB mode set to 'stop'.

$ sc_cli pab_control free_run
Success: PAB mode set to 'free_run'.

$ sc_cli pab_enable enable
Success: PAB enabled.

$ sc_cli get_pab_result 1
PAB Stage 1 Results:
  Status                      : OK
  Message                     : Stage 1 completed successfully
  RX ADC LNA Gain (dB)        : 2.74
  NP DS Att Before LNA (dB)   : 20.00
  NP DS Att Between LNA (dB)  : 13.00
  NP DS Att After LNA (dB)    : 14.00
  US FDX In Att (dB)          : 31.50
  US FDX Out Att (dB)         : 31.50
  US Legacy Att After LNA (dB): 31.50
  US Legacy Att Before LNA (dB): 8.00
  NP DS VCEQ                  : 0.00
  NP DS Inverse EQ            : -0.79
```

The PAB state machine, as observed:

| After | Enabled | Completed | Running Mode | Running Status | Current Stage |
| --- | --- | --- | --- | --- | --- |
| `pab_control stop` | Yes | Yes | STOP | DONE | IDLE |
| `pab_control free_run` | Yes | No | FREERUN | DONE | STAGE1 |
| a round in progress | Yes | No | FREERUN | CONTINUE_DELAY | STAGE5 |
| the round is over | Yes | Yes | FREERUN | DONE | IDLE |

So `Running Status = DONE` on its own does **not** mean the round is over: it
also reads DONE while the round is at STAGE1. A suite that waits for the round
has to wait for `Completed = Yes` and `Current Stage = IDLE` together.

### ASC

```
$ sc_cli get_asc_config
operationMode = FreeRun
inputInterval = 60
outputInterval = 600
clippingInterval = 2
inputPowerTransientThreshold = 0.500000
deltaPilotDiffThreshold = 0.700000
maxPositiveAdjustment = 4.000000
maxNegativeAdjustment = -4.000000
firstPilotFrequency = 453000000
secondPilotFrequency = 711000000
thirdPilotFrequency = 1095000000

$ sc_cli get_asc_fsm_status np_ds
fsm            : NpDs
enabled        : false
loop_count     : 0
current_stage  : Idle
next_stage     : Measure
running_status : Idle

$ sc_cli asc_sim_status
mode            : normal
record_path     : /tmp/asc_sim/record
replay_path     : (unset)
trace           : sp_ds=off np_ds=off np_us=off
rounds_recorded : 0
scenario_id     : (none)
last_result     : (none)

$ sc_cli asc_calib_snapshot show
calibration / store           : in progress
last store round              : round 4 completed (sp_ds_target=stored np_ds_set=stored)
ds_end_frequency_hz           : 1218000000 Hz
calib_npf_tcp                 : 32.11 dBmV
calib_npd_tcp                 : 22.95 dBmV
calib_ds_spf_tcp              : 19.01 dBmV
target_soc_in_tcp             : 33.34 dBmV
pilot_goertzel                : 12 entries
       165000000 Hz      9.85 dBmV
       ...

$ sc_cli asc_calib_snapshot dump /tmp/asc_snap_probe.json
asc_calib_snapshot dump: 2669078 bytes written to /tmp/asc_snap_probe.json (a calibration data store is pending/running)
```

`asc_calib_snapshot dump` writes a JSON file whose top level carries
`calib_ds_spf_tcp`, `calib_npd_tcp`, `calib_npf_tcp`, `ds_end_frequency_hz`,
`calibration_state` (the attenuation and tilt values) and `fdx_path_gain_cal`
(the per frequency gain).

### AGC

```
$ sc_cli get_agc_config
pathloss change ATT Threshold: 0.300000
pathloss change EQ Threshold: 0.300000
AFE TCP Monitor enable: true
Legacy enable: true
Fdx enable: true
NP input adjust count: 3
WBFFT linear start frequency: 450000000
Track eCM power enable: true
NP Clipping Guardrail: 2.000000
SP Clipping Guardrail: 1.000000
Rfboard notify interval: 86400
Telemetry temperature threshold: 1.000000
Telemetry ATT threshold: 0.010000
Telemetry EQ threshold: 0.010000
Telemetry persist interval: 86400
Low power condition threshold: -8.000000
First Out Range MAX TCP: 39.000000
First Out Range Adjust Count: 100
```

`sc_cli set_agc_config <config ID> <value>` takes the index of the **internal
field table**, which is *not* the order of the lines above. The index table
was measured on the DUT: every SET logs the field it touched
(`sc_cli: libsc_agc_set_agc_config - setting <FIELD>`) and the value shows up
in `/mnt/sc_nonvol/agc_data.json`.

| Index | Field in the syslog | Line of `get_agc_config` |
| --- | --- | --- |
| 1 | US_FDX_OUT_ATT_THRESHOLD | pathloss change ATT Threshold |
| 2 | US_FDX_OUT_EQ_THRESHOLD | pathloss change EQ Threshold |
| 3 | LEGACY_FLAG | Legacy enable |
| 4 | FDX_FLAG | Fdx enable |
| 5 | NP_INPUT_ADJUST_COUNT | NP input adjust count |
| 6 | NP_DS_MONITOR_FLAG | AFE TCP Monitor enable |
| 7 | NP_DS_START_FREQ | WBFFT linear start frequency |
| 8 | TRACK_ECM_PWR_FLAG | Track eCM power enable |
| 9 | NP_CLIPPING_GUARDRAIL | NP Clipping Guardrail |
| 10 | SP_CLIPPING_GUARDRAIL | SP Clipping Guardrail |
| 11 | RFBOARD_NOTIFY_INTERVAL | Rfboard notify interval |
| 12 | TELEMETRY_TEMPERATURE_THRESHOLD | Telemetry temperature threshold |
| 13 | TELEMETRY_ATT_THRESHOLD | Telemetry ATT threshold |
| 14 | TELEMETRY_EQ_THRESHOLD | Telemetry EQ threshold |
| 15 | TELEMETRY_PERSIST_INTERVAL | Telemetry persist interval |
| 16 | LOW_PWR_CONDITION_THRESHOLD | Low power condition threshold |
| 17 | FIRST_OUT_RANGE_MAX_TCP | First Out Range MAX TCP |
| 18 | FIRST_OUT_RANGE_ADJUST_COUNT | First Out Range Adjust Count |

Only the block of the flags is in a different order than the display: the
display prints "AFE TCP Monitor enable" before "Legacy enable", the index
table has "Legacy enable" first. Every other index is the line number of
the display, one based.

### The reset leaves the file truncated

`sc_cli reset_agc_config` writes `/mnt/sc_nonvol/agc_data.json` without its
last bytes, so the file is not valid JSON right after the reset (1626 bytes
instead of 1634, the parser stops at the last character). The ASC service
writes the file again in one of its rounds, and then it parses. A suite that
reads the file after a reset has to wait for that round, which takes up to
the input interval of the ASC.

### The read back does not follow the set

On the bench unit of this firmware the SET reaches the configuration and the
read back does not:

- `sc_cli set_agc_config N V` prints `set_agc_config...success`,
- the ASC service logs `setting <FIELD>` and rewrites
  `/mnt/sc_nonvol/agc_data.json` atomically,
- the new value **is** in that file,
- but `sc_cli get_agc_config` keeps the values it had before, for every one
  of the 18 indices.

The mismatch is not only about the values that were set: the file holds
`legacy_flag: true` and `fdx_flag: true` while the command prints
`Legacy enable: false` and `Fdx enable: false`. The file
`/mnt/sc_nonvol/agc_data.json.bak` is the state before the configuration was
written for the first time.

### Everything else

```
$ sc_cli get_adu_status
state=2 name=ON_HOLD

$ sc_cli get_calib_req_config_flag
flag: true

$ sc_cli get_interference_ratio_based
get_interference_ratio_based success (value=3.000000 db)

$ sc_cli get_legacy_rlsp north
North Port rlsp: 8.000000 dBmv

$ sc_cli get_max_ecm_tx_power
get_max_ecm_tx_power success (value=52.750000 dbmV)

$ sc_cli get_min_ecm_tx_power
get_min_ecm_tx_power success (value=17.250000 dbmV)

$ sc_cli get_north_afe_back_off
afe: 3.062500

$ sc_cli get_np_soc_target_tcp
palGetNorthAfeInputTargetTcp success (value=33.099998 dBmV)

$ sc_cli get_station_mode
station mode: with_cable_sim

$ sc_cli get_ds_output_atten
GetDsOutputAtten: attenuation=8.000000

$ sc_cli get_us_fdx_atten
GetUsFdxAtten: attenuation=31.500000

$ sc_cli get_us_fdx_input_atten
GetUsFdxInputAtten: attenuation=31.500000

$ sc_cli get_north_port_switch
GetNorthPortSwitch: Downstream

$ sc_cli get_amplifier_type
Amplifier type is Mini Bridger

$ sc_cli get_single_mode_gain_delta
get_single_mode_gain_delta success (value=1.000000 dB)

$ sc_cli get_cascade_mode_gain_delta
get_cascade_mode_gain_delta success (value=1.000000 dB)

$ sc_cli get_alignment_eq_adjustment_step
get_alignment_eq_adjustment_step success (value=0.500000 dB)

$ sc_cli get_configuration_state
configuration_state: 4

$ sc_cli get_north_port_status 0
enabled = 1
rx_adc_backoff_db = 19.562500
rx_adc_lna_gain_db = 2.847656
measured_rx_adc_backoff_db = 19.570312
rx_adc_input_power_dbmv_tcp = 35.643831
rx_adc_lna_gain_frozen = 0
rx_adc_lna_mode = 2
rx_adc_clip_count = 225
nominal_rx_adc_backoff_db = 16.500000
rx_adc_pga_gain_code = 117.468750
Number of pu32_upstream_pre_equalizer_coefficients = 1024
upstream_pre_equalizer_coefficients_sha256sum = '9f52dd52293d580755d808726187108d4280f2ddb5355de924ea0389190e6fa1'
pu32_upstream_pre_equalizer_coefficients = [
0, 0, ... (1024 values)
]

$ sc_cli get_dpm_configuration
dpm_enable: false
dpm_config:
  periodic_interval_ms: 0
  num_of_wbfft_captures: 0
  num_of_aggregation: 0
  startup_delay_ms: 0
wbfft_config:
  start_hz: 0
  ...

$ sc_cli get_spectrum_allocation
description: Amp-Spectrum-Allocation
dsBeginHz: 108000000
dsEndHz: 1218000000
usLegacyBeginHz: 5000000
usLegacyEndHz: 85000000
usExtendedBeginHz: 108000000
usExtendedEndHz: 396000000
subbandModesCount: 3
subband_modes: [1,1,1,]
freqExclusionCount: 1
frequency_exclusions:
  - index: 0
    description: Frequency-Exclusion
    startHz: 383000000
    endHz: 396000000
    dsType: 2 (DS_EXCLUSION_PASS_OTHER)
    usType: 3 (US_EXCLUSION_EXCLUDED)

$ sc_cli get_reboot_reason
(no output)

$ sc_cli get_dat_offset
DAT Offset Information:
  1.2GHz Offset: N/A (file not found)
  1.8GHz Offset: N/A (file not found)
```

Note the two separator styles: the PAB status uses `key : value`, the ASC
config uses `key = value`, and the AGC config uses `key: value` without a
space before the colon. `IT COMMON - Get Cli Field` accepts all three.

## sc_rfboard_cli

```
$ sc_rfboard_cli board_state
RF board state: ACTIVE

$ sc_rfboard_cli get_attenuation 0
  1 => NP_DS_ATT_BETWEEN_LNAS (actual value 1.77 dB, raw 302) [volatile = 1.76 dB, last_set = 1.76 dB, config = 1.76 dB, default = 16.00 dB] [minimum = -0.01 dB, maximum = 31.13 dB]
  2 => SP_DS_ATT (actual value 8.00 dB) [volatile = 8.00 dB, ...]
  3 => US_LEGACY_ATT_AFTER_LNA (actual value 10.00 dB) [...]
  4 => US_FDX_IN_ATT (actual value 31.50 dB) [...]
  5 => US_FDX_OUT_ATT (actual value 31.50 dB) [...]
  6 => US_LEGACY_ATT_BEFORE_LNA (actual value 8.00 dB) [...]
  7 => NP_DS_ATT_AFTER_LNA (actual value 13.50 dB) [...]
  8 => NP_DS_ATT_BEFORE_LNA (actual value 0.00 dB) [...]

$ sc_rfboard_cli get_var_tilt 0
  1 => SP_DS_1.8G_VEQ (actual value 16.00 dB, raw 3732) [...]
  2 => SP_DS_1.2G_VEQ (actual value 11.70 dB, raw 1769) [...]
  3 => US_FDX_OUT_VCEQ (actual value 11.00 dB, raw 1976) [...]
  4 => NP_DS_VCEQ (actual value 7.21 dB, raw 1787) [...]

$ sc_rfboard_cli get_pa_current 0
  1 => DS_HYBRID_PA_BIAS (actual value 528.00 mA, raw 1000) [...]
  2 => DS_DRIVER_BIAS (actual value 498.50 mA, raw 3635) [...]
  3 => US_FINAL_PA_BIAS (actual value 498.50 mA, raw 3690) [...]

$ sc_rfboard_cli get_board_control 0
  1 => RF_I2C_BUFFER_EN (Enable)
  2 => RF_POWER_EN (Enable)
  3 => RF_PA0_POWER_EN (Enable)
  4 => RF_DAC_I2C_BUFFER_EN (Enable)
  5 => RF_FREQ_1_8G_SW_EN (DS 1.2Ghz)
  6 => RF_FREQ_PWR_SW (8V)

$ sc_rfboard_cli get_rfboard_temperature all
Reading Temperature values...
CHANNEL LOCAL| 59.8125 degC (valid=valid, timestamp_ms=576019755)
CHANNEL 1| 59.125 degC (valid=valid, timestamp_ms=576019755)
CHANNEL 2| 63.4375 degC (valid=valid, timestamp_ms=576019755)
CHANNEL 3| 57.25 degC (valid=valid, timestamp_ms=576019755)

$ sc_rfboard_cli get_auto_adj_legacy_vatt
get_auto_adj_legacy_vatt = 1
get_auto_adj_legacy_vatt...success

$ sc_rfboard_cli get_ignore_np_ds_calib_adj
get_ignore_np_ds_calib_adj = 0
get_ignore_np_ds_calib_adj...success

$ sc_rfboard_cli get_ignore_reset_fdx_us
get_ignore_reset_fdx_us = 0
get_ignore_reset_fdx_us...success

$ sc_rfboard_cli get_ignore_restore_agc_adj
get_ignore_restore_agc_adj = 0
get_ignore_restore_agc_adj...success

$ sc_rfboard_cli get_legacy_up_jxp_tilt
get_legacy_up_jxp_tilt = 3
get_legacy_up_jxp_tilt...success

$ sc_rfboard_cli get_np_monitor_input
Input is north port downstream

$ sc_rfboard_cli get_rf_frequency
RF frequency mode is set to 1.2G

$ sc_rfboard_cli adjust_np_ds_atts_result
	SoC-IN DS AFE Target TCP Setting 36.00 dB
Insert loss(dB)
	BEFORE_LNA exclude ATT1        8.00 dB
	Between_LNA exclude ATT2       3.00 dB
	After_LNA exclude ATT1         3.00 dB
	Total plus ATT                 29.75 dB
Default
	NP_DS_ATT_BEFORE_LNA           0.00 dB
	NP_DS_ATT_BETWEEN_LNAS         2.25 dB
	NP_DS_ATT_AFTER_LNA            13.50 dB
	NP_DS_VCEQ                     7.21 dB
	NP_DS_INVERSE_EQ               -0.79 dB
	Gain H14                       9.75 Flat
After stage1 Cal
	NP_DS_VCEQ                     7.21 dB
	NP_DS_INVERSE_EQ               -0.79 dB
	ATT Change Total Need          -0.50 dB
	SoC-IN DS AFE TCP Actual       36.00 dBmV

$ sc_rfboard_cli eeprom_get_partition_tale
EEPROM Partition Table:
--------------------------------------------------------------------------------
| ID         | Name       | Start    | End      | Size     | FileSize   |
--------------------------------------------------------------------------------
| 1          | RFB_DATA   | 0x00002D | 0x001F9C | 8048     | 1357       |
  MD5: 71F6F5F89EA2D80A45597AA72443BCCC
| 2          | S2P_DATA   | 0x001F9D | 0x0F8B7F | 1010659  | 161144     |
  MD5: 85D68451B168B0197CB6FDAE3029716E
```

Note `get_auto_adj_legacy_vatt` and the other flag getters print the value on a
line of their own and `...success` on the next one.

## sc_amphal_cli

```
$ sc_amphal_cli get_ecm_status
eCM status = Operational

$ sc_amphal_cli get_np_config
north port configuration:
  rx_adc_backoff_db: 16.500
  downstream_plus_interference_to_downstream_ratio_db: 3.062
  rx_adc_lna_mode: FreeRunning
  rx_adc_lna_gain_db: 2.740
  target_rx_adc_input_power_dbmv_tcp: 33.100
  downstream_interference_suppression_threshold_db: 1.000
  upstream_pre_equalizer_coefficients (n=1024):
    [0] 0
    ...

$ sc_amphal_cli get_sp_config
south port configuration:
  target_receive_power_dbmv_per_6_4_mhz: 8.000
  rx_adc_backoff_db: 16.500
  nc_adc_backoff_db: 16.500
  rf_to_nc_attenuation_db: 31.500
  downstream_shaping_filter_gain_db: 0.000
  downstream_shaping_filter_coefficients (n=65):
    [0] 23
    ...

$ sc_amphal_cli get_np_mon_status DS 0
north port monitor:
  enabled: 1
  switch: DS
  measured_rx_adc_backoff_db: 17.496
  rx_adc_lna_gain_db: 32.887
  rx_adc_input_power_dbmv_tcp: 9.397
  rx_adc_clip_count: 0
```

`get_sp_status` and `get_np_status` need the reset flag: `get_np_status 0`.

## sc_msc_cli

```
$ sc_msc_cli get_msc_state
MSC state: RUNNING (3)

$ sc_msc_cli get_msc_controller
MSC controller: NONE (0)

$ sc_msc_cli get_msc_stats
MSC stats:
  successful_forwards : 470543
  failed_forwards     : 0

$ sc_msc_cli get_mgc_timeout
MGC timeout: 300 seconds

$ sc_msc_cli get_bypass_controller_decision
Bypass controller decision: disabled
```

## The Broadcom HAL (`debug hal`)

The HAL is not a program of the eAMP: it is the Broadcom CLI that the AMP
talks to over `/tmp/brcmhal.sock`. The DUT carries the client
(`/usr/bin/cliwrapper_client`) and the socket is there.

**The interactive way** (what the User Guide shows, chapter 7.2.1 step 6):

```
FDX-AMP>$ debug hal
Trying to connect...
Connected.
Press Ctrl-D to exit
                      <- the prompt "hal>" is NOT here yet
                      <- an empty line (just Enter) makes it appear
hal> /leap/np_dac_power_mode_set 0 0

Successfully set NP-DAC power mode

hal>                      <- Ctrl-D leaves it, the clish prompt comes back
```

The prompt only shows up **after an empty line**: the wrapper prints the
banner and then waits for a line of input. A client that waits for the
prompt without the nudge sees a session that hangs.

**The one shot way** (what the AMP itself uses, `palAmpPrivateAPI.c`,
`palSetFdxUsDac()`):

```
$ cliwrapper_client -s /tmp/brcmhal.sock -c '/leap/np_dac_power_mode_set 0 0' -t 2000
/leap/np_dac_power_mode_set 0 0hal> /leap/np_dac_power_mode_set 0 0

Successfully set NP-DAC power mode
```

`-d` sends the command raw, `-c` sends it and adds an empty command whose
error (`'' is not a valid command table`) lands in the output. Both forms
run the command; `-d` keeps the output clean.

Note: `palSetFdxUsDac()` is defined but **never called** anywhere in the AMP
source, so the AMP itself never switches the DAC on its own.

## gNMI

`gnmic -u gnmi -p sercommgnmi -a 127.0.0.1:9339 --insecure get --path '<path>'`
answers with a JSON **array**:

```json
[
  {
    "source": "127.0.0.1:9339",
    "timestamp": 576086015167459,
    "time": "1970-01-07T16:01:26.015167459Z",
    "updates": [
      {
        "Path": "pab-result/stage-1",
        "values": {
          "pab-result/stage-1": {
            "message": "Stage 1 completed successfully",
            "np-ds-att-after-lna": 14,
            "np-ds-att-before-lna": 20,
            "np-ds-att-between-lna": 13,
            "np-ds-inverse-eq": -0.79,
            "np-ds-vceq": 0,
            "rx-adc-lna-gain-db": 2.74,
            "status": "OK",
            "us-fdx-in-att": 31.5,
            "us-fdx-out-att": 31.5,
            "us-legacy-att-after-lna": 31.5,
            "us-legacy-att-before-lna": 8
          }
        }
      }
    ]
  }
]
```

So the leaf is at `response[0]["updates"][0]["values"][path]`, which is what
`IT COMMON - Gnmi Get Leaf Value` does.

The leaves of the PAB stages, as observed on the DUT:

| Path | Leaves |
| --- | --- |
| `pab-result/stage-1` | message, np-ds-att-after-lna, np-ds-att-before-lna, np-ds-att-between-lna, np-ds-inverse-eq, np-ds-vceq, rx-adc-lna-gain-db, status, us-fdx-in-att, us-fdx-out-att, us-legacy-att-after-lna, us-legacy-att-before-lna |
| `pab-result/stage-2` | fdx-clip-count, fdx-stable-cnt, message, nafe-clip-count, nafe-stable-cnt, np-ds-att-after-lna, np-ds-att-before-lna, np-ds-att-between-lna, status |
| `pab-result/stage-3` | message, np-ds-att-before-lna, np-ds-att-between-lna, np-f-tcp, status |
| `pab-result/stage-4` | message, np-afe-tcp, np-ds-att-after-lna, np-ds-att-between-lna, run-iteration, status, target-tcp |
| `pab-result/stage-5` | first-lna-output-tcp, message, np-afe-tcp, np-ds-att-after-lna, np-ds-att-before-lna, np-ds-att-between-lna, np-ds-inverse-eq, np-ds-vceq, real-np-input-tcp, run-iteration, second-lna-output-tcp, status, target-tcp |
| `pab-result/stage-6` | fdx-clip-count, fdx-stable-cnt, message, nafe-clip-count, nafe-stable-cnt, np-ds-att-after-lna, np-ds-att-before-lna, np-ds-att-between-lna, status |
| `pab-result/stage-7` | ecm-online, message, status |

`pab-result` (the whole container) carries the seven stages under the same
leaf names.

The paths the IT template uses:

```
pab-result
pab-result/stage-1 .. pab-result/stage-7
amp-identification
amp-alignment[alignment-type=ALIGN_DOWNSTREAM_STAGE_1]        (and _2, _3, ALIGN_NETWORK, ALIGN_UPSTREAM)
amp-alignment[alignment-type=...]/alignment-status
amp-alignment[alignment-type=...]/alignment-status-update-time
configuration-status
configuration-status/spectrum-state
ds-monitor-data
extended-upstream-spectrum-status
fallback-status
north-port-monitor-status
north-port-status
segment-allocation
software-upgrade
software-upgrade-status[file-name=*]
south-port-status
system-status
wbfft-capture
```

`amp-identification` carries the components and the identity of the DUT:

```json
"amp-identification": {
  "capabilities": { "features": [ "mid-split-v1", "fdx-enablement", ... ] },
  "components": {
    "Main Board": { "model-number": "STL-LE-SOC", "name": "Main Board",
                    "production-date": "2524", "serial-number": "SCMLSC25240006",
                    "software-version": "00.04.006ER3" },
    "RF Board": { "model-number": "STL-LE-RF-M2", "serial-number": "SCMLF225240151", ... },
    ...
  },
  "device-location": { "description": "sercomm", "geo": { ... } },
  "device-mac-address": "78:b3:9f:5c:a0:ef",
  "hardware-version": "04.0",
  "model-number": "STL-LE-SOC",
  "serial-number": "SCMLSC25240006",
  "software-version": "00.04.006ER3",
  "vendor-id": 915,
  "vendor-name": "SERCOMM"
}
```

The serial number is `${DUT_IT_SERIAL}` in `variables/dut_variables.robot`, so a
suite can compare the gNMI answer against the expected DUT.

### The paths of an answer are not the paths of the request

Three things about the paths decide how a value is looked up, and all three
were observed on the DUT:

- gnmic writes the path of an update **without the leading slash**, so
  `updates[0]["Path"]` is `amp-generation/version` and not
  `/amp-generation/version`. A comparison of the two never matches.
- The key of a value is the path **without its key selectors**, e.g. the
  answer of `/ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/data-set-name`
  holds the value under `ds-profile/ds-port-configuration/data-set-name`.
- A key selector names the key of the level **below** it. The JSON of the
  ds-profile is
  `ds-profile -> ds-port-configuration -> AMP_PORT_NORTH -> data-set-name`
  while the path is
  `ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/data-set-name`.

`lib/Viper/GnmiPath.py` does that lookup, and
`IT COMMON - Gnmi Get Leaf Value` uses it.

A GET with a wildcard answers with one update per matched instance, e.g.
`amp-alignment[alignment-type=*]` answers with the five alignment types. The
path of such an update carries the instance, e.g.
`amp-alignment[alignment-type=ALIGN_UPSTREAM]`.

### A SET needs the --update flag

```
gnmic ... set --update /amp-alignment[alignment-type=ALIGN_UPSTREAM]/alignment-type:::string:::ALIGN_UPSTREAM
```

Without `--update` gnmic refuses the request with
`Error: no paths or request file provided` and nothing reaches the DUT.

A refused SET is reported on **stderr** and gnmic still exits with 0, so the
exit status says nothing about the request. The error text is the only
evidence, e.g. `internal set failed: Invalid input param`.

### Alignment stage behavior depends on the run

An earlier bench observation showed stages following one DS1 SET:

```
SET /amp-alignment[alignment-type=ALIGN_DOWNSTREAM_STAGE_1]/alignment-type
  22:03:00  ALIGN_DOWNSTREAM_STAGE_1  ALIGN_STATUS_IN_PROGRESS
  22:03:17  ALIGN_DOWNSTREAM_STAGE_1  ALIGN_STATUS_ALIGNED
  22:03:29  ALIGN_DOWNSTREAM_STAGE_2  ALIGN_STATUS_ALIGNED
  22:03:49  ALIGN_DOWNSTREAM_STAGE_3  ALIGN_STATUS_IN_PROGRESS
  ...       ALIGN_UPSTREAM             ALIGN_STATUS_ALIGNED
```

On 2026-11-23, however, a DS1 SET on `.233` (HW 06.05, SW 00.04.006)
completed DS1 but left DS2, DS3, and US `ALIGN_STATUS_UNALIGNED`; they were
ALIGNED before the SET. The reason for the difference has not been established.
Do not assume that triggering DS1 completes the other stages.

While the flow runs, every other alignment request is refused:

```
internal set failed: cannot process parallel tasks
```

So a suite that triggers a stage has to wait until no stage reports
`ALIGN_STATUS_IN_PROGRESS` before it sends its own request. The waiting is
done by `IT COMMON - Wait For No Gnmi Instance With`.

An earlier isolated-stage run ended in `ALIGN_STATUS_FAILURE` when earlier
stages were not aligned. On 2026-11-23, triggering DS1, DS2, DS3, and US
individually in that order succeeded. The suites check earlier stages before
triggering a later one.

DS3 can emit repeated `ALIGN_STATUS_IN_PROGRESS` notifications before its
final `ALIGN_STATUS_ALIGNED`; one repeated progress event is not a failure.

### The answer of a GET can lag the request

Right after a SET, the answer of a GET can still carry the leaf of the state
before the request, e.g. a GET of `alignment-status-update-time` answered
with `alignment-status`. A suite that polls for a change reads the leaf
tolerantly (`IT COMMON - Gnmi Get Leaf Value Or Default`) and waits for the
update time to change, which tells a fresh answer from the old one.

## gRPC

`grpcurl -plaintext -import-path /etc/amp/proto/ -proto <file>.proto -d '<json>'
127.0.0.1:9338 <service>/<method>`

The protos on the DUT are `asc_config.proto`, `calibration.proto`,
`ds_periodic_maintanence.proto`, `fdx_enablement.proto`, `gnmi.proto`,
`gnmi_ext.proto`, `hw_installation.proto`, `internal.proto`, `pab_config.proto`,
`running_configuration.proto`, `us_fdx_dac.proto`, `wbfft_capture.proto`,
`goertzal_measure.proto`.

The services and their methods:

| Service | Methods |
| --- | --- |
| `gnoi.pab_config.v1.PabConfig` | GetPabConfiguration, SetPabConfiguration, GetPabStatus, SetPabCommand |
| `gnoi.asc_config.v1.AscConfigService` | GetAscConfiguration, SetAscConfiguration |
| `gnoi.calibration.v1.Calibration` | StartCalibration (server stream), GetCalibrationStatus |
| `gnoi.hw_installation.v1.HwInstallation` | GetPreAlignmentStatus, SetInitialConfiguration, StartCalibration (server stream) |
| `gnoi.ds_periodic_maintanence.v1.DownstreamPeriodicMaintanence` | GetDpmConfiguration, SetDpmConfiguration, UpgradeDpm, RefreshDpmOperation, GetFinalMeasurementVector, GetBcmFinalAdjustmentVector, GetLastMeasurementSet, GetDebugInfo (server stream) |
| `gnoi.us_fdx_dac.v1.UsFdxDacController` | SetUsFdxDacPowerModeVolatile, GetUsFdxDacPowerModeVolatile |
| `gnoi.wbfft.v1.WbfftCapture` | GetWbfftCapture (server stream) |

On `.233` with firmware `00.04.006`, `Calibration.StartCalibration` AUTO
and SEMI_AUTO from DS1 emitted DS1, DS2, DS3, US1 progress in order and a
SUCCESS; SEMI_AUTO did not request a manual adjustment in that run. MANUAL
DS1 emitted DS1 and SUCCESS only, and the subsequent status reported DS2,
DS3 and US1 UNALIGNED. The adjustment and failure stream branches have not
been produced on that DUT. `GetCalibrationStatus` omitted `isCalibrating`
when false, consistent with proto3's default-value JSON encoding.

The answers:

```json
{
  "success": { "status": "SUCCESS", "message": "Get PAB Configuration completed successfully" },
  "pabConfig": {
    "rxAdcLnaGain": 2.74,
    "pabTargetTcp": 36,
    "checkEcmOnlineInterval": 60,
    "pabRetryInterval": 60,
    "rpdPwrdThreshold": -21.78,
    "outlierThreshold": 6
  }
}
```

```json
{
  "success": { "status": "SUCCESS", "message": "Get PAB Status completed successfully" },
  "pabStatus": {
    "enabled": true,
    "isCompleted": true,
    "loopCount": 1,
    "ecmOnline": true,
    "runningMode": "ALIGN_PAB_MODE_FREERUN",
    "currentStage": "ALIGN_PAB_STAGE_IDLE",
    "runningStatus": "ALIGN_PAB_STATUS_DONE"
  }
}
```

```json
{
  "success": { "status": "SUCCESS", "message": "GetPreAlignmentStatus completed successfully" },
  "ecmRegistration": true,
  "northPortInputTcp": 35.678987239838875,
  "northPortMonitorDsInputTcp": 9.38946731397074,
  "upstreamProfile": [ { "portType": "SOUTH_PORT", "targetReceivePowerDbmvPer64Mhz": 8 }, ... ],
  "legacyUsInputAttenuations": [ { "spType": "SOUTH_PORT_TYPE_MAIN_PORT", "value": 0, "attenuation": 8 } ],
  "legacyUsPostLnaAttenuations": [ ... ]
}
```

```json
{
  "success": { "status": "SUCCESS", "message": "GetDpmConfiguration completed successfully" },
  "enabled": true,
  "configuration": { "periodInSeconds": 600, "numberOfWbfftCaptures": 200, "numberOfAggregation": 60 },
  "wbfftCaptureConfiguration": {
    "startFrequencyHz": 108000000, "endFrequencyHz": 1218000000,
    "fftSize": 16384, "samplingRateHz": 1647000000,
    "outputFormat": "OutputFormat_FreqDomainPower", "windowingMode": "WindowingMode_None",
    "averagingMode": "AveragingMode_Time", "outputScale": 6, "aggregationPeriodMs": 200,
    "samplePoint": "SamplePoint_NpD", "measurementRateMs": 1, "totalMeasurementDurationMs": 200
  },
  "adjustmentThresholdRange": [ { "minValue": 188946946, "maxValue": 381364161 } ]
}
```

A failed call carries a `failure` object instead of a `success` one:

```json
{ "failure": { "status": "FAILURE", "message": "failed RfiHalCfg::startWbfftMeasurement" } }
```

The server does **not** support the gRPC reflection API, so the proto file has
to be named with `-proto`.

## The files of the DUT

```
/mnt/sc_nonvol/ampapp_data.json
/mnt/sc_nonvol/agc_data.json
/mnt/sc_nonvol/agc_telemetry_data.json
/mnt/sc_nonvol/asc_calib_snapshot.json
/mnt/sc_nonvol/pab_results.json
/mnt/sc_nonvol/rfboard_data.json
/mnt/sc_nonvol/rfboard_data.json.default
/mnt/sc_nonvol/s2p_files
/etc/amp/proto/
/sc_versions.txt
```

## The management IP and the factory default

Measured on the bench unit, image 00.04.006.

- The management settings live in the AMP nonvol store, in
  `/mnt/sc_nonvol/ampapp_data.json`:
  `"management": {"interface": {"address", "gateway", "mode", "netmask"}}`.
- At boot the address comes from that file: `/etc/network/interfaces` holds
  `iface eth0 inet manual` and the pre-up hook
  `/usr/bin/scPortBringup.sh up eth0` reads it with
  `sc_cli get_mgmt_port_config` and puts it on eth0.
- `mgmtip show | dhcp | static ip <ip> net-mask <mask> gateway <gw>`
  (User Guide 10.6) writes the store and restarts `sc_eth0`, so the new
  address is live at once. The store writes the file **in the same second**,
  several atomic writes in a row, so the value is on disk before any reboot.
- `restore factory config` (User Guide 10.3) runs `/usr/bin/reset.sh
  RESET_FACTORY`, which sets `/system-control/reset-control/reset =
  RESET_FACTORY` over gNMI. The AMP then **reboots the DUT by itself**:
  the SSH connection is gone 15 s after the command and the unit is back
  about 40 s later. There is no window to run `mgmtip static` in between.
- What the DUT comes back with depends on the unit. The factory data of a
  unit that the bench provisioned carries the bench address, so the address
  does not change. The factory data of the image
  (`/card0/amp/ampapp_data.json.default`) carries `192.168.2.103`, so a unit
  that was never provisioned comes back on that address and is out of reach.

## Notes that save a suite from a wrong assertion

- `sc_cli get_reboot_reason` prints nothing when there is no reason recorded.
  A suite that checks it has to accept an empty output.
- The RF board flag getters print the value and `...success` on two separate
  lines, so the label is the command name itself
  (`get_auto_adj_legacy_vatt = 1`).
- `sc_rfboard_cli get_single_mode_gain_delta` does **not** exist; the gain
  delta getters live on `sc_cli`.
- The `...` in `sc_rfboard_cli adjust_np_ds_atts_result` is a tab, not
  spaces.
- `sc_cli get_north_port_status 0` prints 1024 pre equalizer coefficients, so
  the output is large. Do not put the whole output in an assertion message.
- The login shell of the DUT is clish. A command that comes in over a non
  interactive channel is handed over to `sh` with a fixed buffer: a command
  of 225 characters still works, one of 226 characters is cut and the shell
  answers `sh: -c: line 0: unexpected EOF while looking for matching '"'`.
  The ROOT session is a real bash and takes the whole line, so a long
  command is sent there. `IT COMMON - Run Dut Exec Command And Return` does
  that on its own.
- `sc_cli set_agc_config <index> <value>` is **one based**: the index is the
  number of the row in `sc_cli get_agc_config`, so index 4 is "Legacy
  enable" and index 9 is "NP Clipping Guardrail". The valid range is 1 to 18.
- The clish prompt carries the MAC address of the DUT, e.g.
  `[78:b3:9f:5c:a0:ef]FDX-AMP>$` and
  `[78:b3:9f:5c:a0:ef]FDX-AMP(ds-profile-north)>$`. The prompt of a view is
  matched by its end, so the MAC does not have to be known.
- **The amplifier is given to one service at a time.** The MSC decides, and
  the priority is `NONE < ASC < MGC < PAB = ALN`; PAB and ALN share the top
  and are exclusive. A command that asks for the amplifier is refused while
  the PAB service holds it: `sc_cli calib_us_legacy` answers
  `Failed to request ALN control from MSC, 7` (`7` is
  `LIBSC_CFG_ERES_ERROR`, the answer of the MSC with an error). The PAB
  holds the amplifier for about a minute and gives it back, so a suite that
  needs it runs the command again until it is not refused
  (`IT COMMON - Run Dut Command Until Not Refused`).
- **The banner of the clish has no prompt of its own.** `configure banner
  login` asks for the text and waits for the line that holds only `/end`, so
  a suite sends the text without waiting for a prompt and reads the answer
  of the `/end`. The banner itself shows up in the **SSH banner** of a new
  session, which the server sends as the SSH message `USERAUTH_BANNER`.
  paramiko does not read that message on a client connection, so the library
  catches it in the transport by hand
  (`IT COMMON - Get Dut Login Banner`).
- The banner text is written to `/mnt/sc_nonvol/ssh/.loginBanner` and the
  fragment `99-banner.conf` of `/mnt/sc_nonvol/ssh/sshd_config.d/` points
  the sshd at it. The sshd runs one process per connection
  (`sshd -i -f /etc/ssh/sshd_config_readonly`), so a new session shows the
  banner without a reload.
- The names of the users are looked for with the comma behind them: the
  table of the DUT holds `test1` to `test30`, and `test3` is the start of
  `test30` as well.

## What this firmware does not have

These were measured on the DUT of this bench, image 00.04.006ER3. They are
not bugs of the suites, they are the limits of the image.

| What | What the DUT answers |
| --- | --- |
| `GET /rf-components/...` | `internal set failed: ... missing "index" key in map[]`, the server cannot render the tree because of the list node below `rf-components` |
| `SET /spectrum-allocation/...` | `internal set failed: Invalid input param` |
| `SET /ds-profile/.../data-set-name` | `internal set failed: Invalid input param` |
| `SET /amp-identification/device-location/...` | `internal set failed: Invalid input param` |
| `SET /software-upgrade/update-type` | `SetRequest not valid` |
| `SET /rf-components/north-port-switch-path` | `failed RfiPalCfg::setNorthPortSwitch` |
| `GET /us-profile/us-port-configuration` | `NotFound`, the container has to be read through `/us-profile` |
| `GET /ds-profile/ds-port-configuration` | `NotFound`, the container has to be read through `/ds-profile` |
| `sc_cli get_amp_generation`, `sc_cli get_legacy_us_output_atten` | the command does not exist |
| `dstracker` | not deployed |
| `/card0/...` | the path does not exist |
| `asc_calib_snapshot.json` | never written on this unit |
| `HwInstallation/SetInitialConfiguration` | the answer is a failure, `Failed to set NorthPortConfiguration to HAL` or `Failed to set SouthPortConfiguration to HAL`, depending on the port that is written |
| `HwInstallation/StartCalibration` | the stream reports the progress of the stage and then a failure, `Alignment failed for stage:1`; the bench unit has no signal source |
| the Broadcom CLI wrappers | they connect to their socket and print `Trying to connect... Connected. Press Ctrl-D to exit`. Their prompt (`hal>`, `brcmsystem>`, `brcmupgrade>`) only shows up **after an extra newline**: the wrapper prints the banner and then waits for a line, so the session has to be nudged with an empty line before the prompt appears. With that nudge the prompt comes and the command runs (`/leap/np_dac_power_mode_set 0 0` answers `Successfully set NP-DAC power mode`). Ctrl-D leaves them (`Exiting ...`). The three sockets are there. The `TERM` of the session makes no difference, the DUT has no terminfo at all |

The gNMI trees that are there:

```
amp-identification            amp-generation            ds-profile
us-profile                    spectrum-allocation       software-upgrade
north-port                    amp-alignment[alignment-type=...]
```

