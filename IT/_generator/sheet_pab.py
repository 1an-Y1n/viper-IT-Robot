"""The PAB sheet of the LE IT test template: PAB-002 to PAB-016.

PAB-001 is not here: it was written by hand and is the worked example of the
whole IT suite set.
"""

from writer import C, S

GNMI = "GNMI Result (Container & Stage 1~7)"
GRPC = "GRPC Configuration, Status & Control"

# The leaves of every PAB stage, as the DUT reports them. The template asks
# for exactly these leaves under every stage.
STAGE_LEAVES = {
    "stage-1": [
        "message", "np-ds-att-after-lna", "np-ds-att-before-lna",
        "np-ds-att-between-lna", "np-ds-inverse-eq", "np-ds-vceq",
        "rx-adc-lna-gain-db", "status", "us-fdx-in-att", "us-fdx-out-att",
        "us-legacy-att-after-lna", "us-legacy-att-before-lna",
    ],
    "stage-2": [
        "fdx-clip-count", "fdx-stable-cnt", "message", "nafe-clip-count",
        "nafe-stable-cnt", "np-ds-att-after-lna", "np-ds-att-before-lna",
        "np-ds-att-between-lna", "status",
    ],
    "stage-3": [
        "message", "np-ds-att-before-lna", "np-ds-att-between-lna",
        "np-f-tcp", "status",
    ],
    "stage-4": [
        "message", "np-afe-tcp", "np-ds-att-after-lna", "np-ds-att-between-lna",
        "run-iteration", "status", "target-tcp",
    ],
    "stage-5": [
        "first-lna-output-tcp", "message", "np-afe-tcp", "np-ds-att-after-lna",
        "np-ds-att-before-lna", "np-ds-att-between-lna", "np-ds-inverse-eq",
        "np-ds-vceq", "real-np-input-tcp", "run-iteration",
        "second-lna-output-tcp", "status", "target-tcp",
    ],
    "stage-6": [
        "fdx-clip-count", "fdx-stable-cnt", "message", "nafe-clip-count",
        "nafe-stable-cnt", "np-ds-att-after-lna", "np-ds-att-before-lna",
        "np-ds-att-between-lna", "status",
    ],
    "stage-7": ["ecm-online", "message", "status"],
}

STAGES = ["stage-%d" % number for number in range(1, 8)]


def _stage_suite(item_id, stage, summary, description):
    """One suite that reads the result of a single PAB stage over gNMI."""
    leaves = STAGE_LEAVES[stage]
    S(
        item_id,
        sheet="PAB",
        area=GNMI,
        comment="Read the %s result of the PAB procedure over gNMI" % stage,
        doc=description,
        vars=[("path", "pab-result/%s" % stage)],
        cases=[
            C(
                "GET the %s result over gNMI" % stage,
                doc=[
                    "Step 1. GET pab-result/%s" % stage,
                    "Step 2. Check that every leaf of the stage is present",
                    "Step 3. Check that the stage reports OK",
                ],
                tags=["GNMI"],
                log="1_gnmi.log",
                vars=[("leaves", leaves)],
                body=[
                    "${response}=    IT COMMON - Gnmi Get And Return    ${path}",
                    "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}",
                    "${names}=    IT COMMON - Gnmi Leaf Names Of    ${value}",
                    "IT COMMON - Gnmi Leaves Should Exist    ${names}    ${leaves}",
                    "${status}=    IT COMMON - Get Dict Field    ${value}    status",
                    "Should Be Equal    ${status}    OK",
                ],
            ),
        ],
    )


S(
    "PAB-002",
    sheet="PAB",
    area=GNMI,
    comment="Read the whole PAB result container over gNMI",
    doc="Read the whole PAB result container over gNMI and check that it "
        "holds the payload of every stage, stage 1 to stage 7 (User Guide 9.16.1).",
    vars=[("path", "pab-result"), ("stages", STAGES)],
    cases=[
        C(
            "GET the whole PAB result container over gNMI",
            doc=[
                "Step 1. GET pab-result",
                "Step 2. Check that the container holds the seven stages",
                "Step 3. Check that every stage holds its own leaves",
            ],
            tags=["GNMI"],
            log="1_gnmi.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    ${path}",
                "${container}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}",
                "FOR    ${stage}    IN    @{stages}",
                "    IT COMMON - Gnmi Leaf Should Exist    ${container}    ${stage}",
                "END",
            ],
        ),
        C(
            "Check the leaves of every stage of the container",
            doc=[
                "Step 1. GET pab-result",
                "Step 2. Walk the seven stages and check their leaves",
            ],
            tags=["GNMI"],
            log="2_gnmi.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    ${path}",
                "${container}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}",
                "FOR    ${stage}    IN    @{stages}",
                "    ${leaves}=    IT COMMON - Gnmi Stage Leaves Should Exist    ${container}    ${stage}    ${stage_leaves}[${stage}]",
                "END",
            ],
            vars=[("stage_leaves", STAGE_LEAVES)],
        ),
    ],
)

for _number in range(3, 10):
    _stage_suite(
        "PAB-%03d" % _number,
        "stage-%d" % (_number - 2),
        "Get PAB Result: Stage %d" % (_number - 2),
        "Read the results of PAB stage %d over gNMI and check that the "
        "information of the stage is complete (User Guide 9.16.1)."
        % (_number - 2),
    )

S(
    "PAB-010",
    sheet="PAB",
    area=GRPC,
    comment="Read the PAB configuration over gRPC and cross check it with the CLI",
    doc="Request the PAB configuration with grpcurl and check the pabConfig "
        "object (User Guide 12.1.4.1).",
    vars=[("proto", "pab_config.proto"), ("method", "gnoi.pab_config.v1.PabConfig/GetPabConfiguration")],
    cases=[
        C(
            "GET the PAB configuration over gRPC",
            doc=[
                "Step 1. Call GetPabConfiguration",
                "Step 2. Check that the call succeeded",
                "Step 3. Check the fields of the pabConfig object",
            ],
            tags=["GRPC"],
            log="1_grpc.log",
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "${config}=    IT COMMON - Grpc Get Field    ${response}    pabConfig",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'rxAdcLnaGain']}}    2.74",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'pabTargetTcp']}}    36.00",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'checkEcmOnlineInterval']}}    60",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'pabRetryInterval']}}    60",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'rpdPwrdThreshold']}}    -21.78",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'outlierThreshold']}}    6.00",
            ],
        ),
        C(
            "Cross check the gRPC configuration with the CLI",
            doc=[
                "Step 1. GET the PAB configuration with sc_cli",
                "Step 2. Compare the values of both answers",
            ],
            tags=["GRPC", "CLI"],
            log="2_grpc_cli.log",
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}",
                "${config}=    IT COMMON - Grpc Get Field    ${response}    pabConfig",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config",
                "IT COMMON - Cli Number Should Equal    ${cli}    rx adc lna gain    ${{$config['rxAdcLnaGain']}}",
                "IT COMMON - Cli Number Should Equal    ${cli}    target tcp    ${{$config['pabTargetTcp']}}",
                "IT COMMON - Cli Number Should Equal    ${cli}    online interval    ${{$config['checkEcmOnlineInterval']}}",
                "IT COMMON - Cli Number Should Equal    ${cli}    retry interval    ${{$config['pabRetryInterval']}}",
                "IT COMMON - Cli Number Should Equal    ${cli}    RPD power threshold    ${{$config['rpdPwrdThreshold']}}",
                "IT COMMON - Cli Number Should Equal    ${cli}    outlier threshold    ${{$config['outlierThreshold']}}",
            ],
        ),
    ],
)

S(
    "PAB-011",
    sheet="PAB",
    area=GRPC,
    comment="Read the PAB status over gRPC and cross check it with the CLI",
    doc="Request the PAB status with grpcurl and check the pabStatus object "
        "(User Guide 12.1.4.3).",
    vars=[("proto", "pab_config.proto"), ("method", "gnoi.pab_config.v1.PabConfig/GetPabStatus")],
    cases=[
        C(
            "GET the PAB status over gRPC",
            doc=[
                "Step 1. Wait until the PAB has completed a round",
                "Step 2. Call GetPabStatus",
                "Step 3. Check that the call succeeded",
                "Step 4. Check the fields of the pabStatus object",
            ],
            tags=["GRPC"],
            log="1_grpc.log",
            body=[
                "${response}=    IT COMMON - Wait For Grpc Nested Field Value",
                "...    ${proto}    ${method}",
                "...    ${{['pabStatus', 'isCompleted']}}    True",
                "...    timeout=180    interval=5",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "${status}=    IT COMMON - Grpc Get Field    ${response}    pabStatus",
                "IT COMMON - Grpc Field Should Exist    ${status}    enabled",
                "IT COMMON - Grpc Field Should Exist    ${status}    isCompleted",
                "IT COMMON - Grpc Field Should Exist    ${status}    loopCount",
                "IT COMMON - Grpc Field Should Exist    ${status}    ecmOnline",
                "IT COMMON - Grpc Field Should Exist    ${status}    runningMode",
                "IT COMMON - Grpc Field Should Exist    ${status}    currentStage",
                "IT COMMON - Grpc Field Should Exist    ${status}    runningStatus",
            ],
        ),
        C(
            "Cross check the gRPC status with the CLI",
            doc=[
                "Step 1. GET the PAB status with sc_cli",
                "Step 2. Compare the mode, the stage and the running status of both answers",
            ],
            tags=["GRPC", "CLI"],
            log="2_grpc_cli.log",
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}",
                "${status}=    IT COMMON - Grpc Get Field    ${response}    pabStatus",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                "${cli_mode}=    IT COMMON - Get Cli Field    ${cli}    Running Mode",
                "${grpc_mode}=    IT COMMON - Grpc Get Field    ${status}    runningMode",
                "IT COMMON - Grpc Enum Should Match Cli    ${grpc_mode}    ${cli_mode}",
                "${cli_stage}=    IT COMMON - Get Cli Field    ${cli}    Current Stage",
                "${grpc_stage}=    IT COMMON - Grpc Get Field    ${status}    currentStage",
                "IT COMMON - Grpc Enum Should Match Cli    ${grpc_stage}    ${cli_stage}",
                "${cli_running}=    IT COMMON - Get Cli Field    ${cli}    Running Status",
                "${grpc_running}=    IT COMMON - Grpc Get Field    ${status}    runningStatus",
                "IT COMMON - Grpc Enum Should Match Cli    ${grpc_running}    ${cli_running}",
            ],
        ),
    ],
)

S(
    "PAB-012",
    sheet="PAB",
    area=GRPC,
    comment="Set the PAB configuration over gRPC and check that the values took",
    doc="Set the parameters of the PAB process with grpcurl, check that the "
        "SET was successful and that the GET returns the new values "
        "(User Guide 12.1.4.2).",
    vars=[
        ("proto", "pab_config.proto"),
        ("method", "gnoi.pab_config.v1.PabConfig/SetPabConfiguration"),
        ("get_method", "gnoi.pab_config.v1.PabConfig/GetPabConfiguration"),
        # The configuration that was in place before the case is carried from
        # the first case to the teardown that puts it back, so both variables
        # are declared here and filled in with a suite scope.
        ("original", "${EMPTY}"),
        ("restore_payload", "${EMPTY}"),
    ],
    # The DUT is left with the configuration it had before the suite. The
    # teardown runs after all the cases and it runs even when a case failed,
    # so it is the right place for that.
    teardown=[
        "# Put the PAB configuration back, so the DUT is left as it was.",
        "IT COMMON - Restore Grpc Configuration",
        "...    ${proto}    ${method}    ${get_method}    ${restore_payload}",
        "...    ${{['pabConfig', 'rpdPwrdThreshold']}}",
    ],
    cases=[
        C(
            "SET the PAB configuration over gRPC",
            doc=[
                "Step 1. Read the configuration that is in place now",
                "Step 2. SET the new configuration",
                "Step 3. Check that the SET was successful",
            ],
            tags=["GRPC", "WRITE"],
            log="1_grpc.log",
            vars=[
                ("payload", '{"pabConfig": {"rxAdcLnaGain": 2.74, "pabTargetTcp": 36.0, '
                            '"checkEcmOnlineInterval": 60, "pabRetryInterval": 60, '
                            '"rpdPwrdThreshold": -27.78, "outlierThreshold": 6.0}}'),
            ],
            body=[
                "${before}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "${original}=    IT COMMON - Grpc Get Field    ${before}    pabConfig",
                "VAR    ${original}    ${original}    scope=SUITE",
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "${restore}=    Evaluate    json.dumps({'pabConfig': $original})    modules=json",
                "VAR    ${restore_payload}    ${restore}    scope=SUITE",
            ],
        ),
        C(
            "GET the configuration back and check the new values",
            doc=[
                "Step 1. GET the PAB configuration",
                "Step 2. Compare the values with the ones that were SET",
                "Step 3. Cross check with sc_cli get_pab_config",
            ],
            tags=["GRPC", "CLI", "WRITE"],
            log="2_grpc_cli.log",
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'rxAdcLnaGain']}}    2.74",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'pabTargetTcp']}}    36.00",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'checkEcmOnlineInterval']}}    60",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'pabRetryInterval']}}    60",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'rpdPwrdThreshold']}}    -27.78",
                "IT COMMON - Grpc Number Should Equal    ${response}    ${{['pabConfig', 'outlierThreshold']}}    6.00",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config",
                "IT COMMON - Cli Number Should Equal    ${cli}    rx adc lna gain    2.74",
                "IT COMMON - Cli Number Should Equal    ${cli}    target tcp    36.00",
                "IT COMMON - Cli Number Should Equal    ${cli}    RPD power threshold    -27.78",
                "IT COMMON - Cli Number Should Equal    ${cli}    outlier threshold    6.00",
            ],
        ),
    ],
)

for _item, _command, _mode in [
    ("PAB-013", "START", "FREERUN"),
    ("PAB-014", "STOP", "STOP"),
    ("PAB-015", "RESTART", "FREERUN"),
]:
    # After START and RESTART a round is running, so the case waits for that
    # round to be over. After STOP the procedure is at rest and the stage is
    # IDLE right away.
    _running = _command in ("START", "RESTART")
    # The START is the only command that has to be sent to a PAB that is
    # stopped: a START on a PAB that is still running does not restart the
    # round, so the command would not have the effect the case is about.
    _stop_first = _command == "START"
    # What has to happen before the command goes out, and that is different
    # for every command: a START needs a PAB that is stopped, a STOP needs a
    # PAB that is running, and a RESTART needs a PAB that is at rest.
    if _stop_first:
        _doc = [
            "Step 1. Stop the PAB, so that the command cannot land on a",
            "        round that is still running",
            "Step 2. Call SetPabCommand with %s" % _command,
            "Step 3. Check that the call succeeded",
        ]
    elif _command == "STOP":
        _doc = [
            "Step 1. Start a round, so that the STOP has something to stop",
            "Step 2. Call SetPabCommand with %s" % _command,
            "Step 3. Check that the call succeeded",
        ]
    else:
        _doc = [
            "Step 1. Wait until the PAB is at rest",
            "Step 2. Call SetPabCommand with %s" % _command,
            "Step 3. Check that the call succeeded",
        ]
    S(
        _item,
        sheet="PAB",
        area=GRPC,
        comment="Trigger the PAB control %s over gRPC and check the status" % _command,
        doc="Trigger the pre-alignment balancing procedure with the %s "
            "command of the gRPC API (User Guide 12.1.4.4)." % _command,
        vars=[
            ("proto", "pab_config.proto"),
            ("method", "gnoi.pab_config.v1.PabConfig/SetPabCommand"),
            ("get_method", "gnoi.pab_config.v1.PabConfig/GetPabStatus"),
        ],
        cases=[
            C(
                "Send the %s command over gRPC" % _command,
                doc=_doc,
                tags=["GRPC", "WRITE"],
                log="1_grpc.log",
                vars=[
                    ("payload", '{"pabCommand": {"currentCommand": "%s"}}' % _command),
                    ("stop_payload", '{"pabCommand": {"currentCommand": "STOP"}}'),
                    ("start_payload", '{"pabCommand": {"currentCommand": "START"}}'),
                ],
                body=([
                    # The PAB is stopped first, so that the command cannot land
                    # on a round that is still running: a START on a running
                    # PAB does not restart the round. The DUT applies the STOP
                    # at the next stage boundary, so the mode is waited for
                    # before the command goes out.
                    "${stop}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${stop_payload}",
                    "IT COMMON - Grpc Should Succeed    ${stop}",
                    "${stopped}=    IT COMMON - Wait For Dut Cli Field    sc_cli get_pab_status    Running Mode    STOP    timeout=60    interval=1",
                    "Log    ${stopped}",
                    "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}",
                ] if _stop_first else [
                    # The STOP is only worth something while the PAB is running,
                    # so a round is started first and the command cuts it short.
                    "${start}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${start_payload}",
                    "IT COMMON - Grpc Should Succeed    ${start}",
                    "${running}=    IT COMMON - Wait For Dut Cli Field Different    sc_cli get_pab_status    Current Stage    IDLE    timeout=60    interval=1",
                    "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}",
                ] if _command == "STOP" else [
                    # The PAB has to be at rest before the command, so that the
                    # command is the one that starts the round. The running
                    # mode is not part of this: after the STOP command the PAB
                    # is at rest in the STOP mode, and the RESTART has to work
                    # from there.
                    # The Completed field is not part of this either: a round
                    # that the STOP cut short is not counted as completed, and
                    # the PAB is left in that state by the case before this one.
                    "${rest}=    Create List    Running Status=DONE    Current Stage=IDLE",
                    "${before}=    IT COMMON - Wait For Dut Cli Fields    sc_cli get_pab_status    ${rest}    timeout=120    interval=5",
                    "Log    ${before}",
                    "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}",
                ]) + [
                    "IT COMMON - Grpc Should Succeed    ${response}",
                    "${success}=    IT COMMON - Grpc Get Field    ${response}    success",
                    "${status}=    IT COMMON - Grpc Get Field    ${success}    status",
                    "Should Be Equal    ${status}    SUCCESS",
                ],
            ),
            C(
                "Check the PAB status after the %s command" % _command,
                doc=[
                    "Step 1. Wait until the PAB shows that the command took",
                    "Step 2. Check the running mode of the gRPC answer",
                    "Step 3. Cross check the running mode with sc_cli get_pab_status",
                    "Step 4. The template expects the stage to be STAGE1 right after the",
                    "        command, but the stage walks on by itself, so the stage is",
                    "        not pinned to one value here",
                ],
                tags=["GRPC", "CLI", "WRITE"],
                log="2_grpc_cli.log",
                body=(
                    [
                        # The command has to put the PAB into a round, so the
                        # stage leaves the idle state. The stage walks on by
                        # itself, so it is not pinned to one value.
                        "${cli}=    IT COMMON - Wait For Dut Cli Field Different    sc_cli get_pab_status    Current Stage    IDLE    timeout=60    interval=1",
                        "${cli_mode}=    IT COMMON - Get Cli Field    ${cli}    Running Mode",
                        "Should Be Equal    ${cli_mode}    ${cli_mode_suffix}",
                        "${cli_stage}=    IT COMMON - Get Cli Field    ${cli}    Current Stage",
                        "Should Not Be Equal    ${cli_stage}    IDLE",
                        "${cli_completed}=    IT COMMON - Get Cli Field    ${cli}    Completed",
                        "Should Be Equal    ${cli_completed}    No",
                        "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                        "IT COMMON - Grpc Should Succeed    ${response}",
                        "${status}=    IT COMMON - Grpc Get Field    ${response}    pabStatus",
                        "${mode}=    IT COMMON - Grpc Get Field    ${status}    runningMode",
                        "Should Be Equal    ${mode}    ALIGN_PAB_MODE_${mode_suffix}",
                        "${stage}=    IT COMMON - Grpc Get Field    ${status}    currentStage",
                        "Should Not Be Equal    ${stage}    ALIGN_PAB_STAGE_IDLE",
                    ]
                    if _running
                    else [
                        # The command has to stop the PAB, so the mode changes
                        # to STOP. The DUT applies the command at the next
                        # stage boundary, so the mode is waited for.
                        "${cli}=    IT COMMON - Wait For Dut Cli Field    sc_cli get_pab_status    Running Mode    ${cli_mode_suffix}    timeout=120    interval=1",
                        "${cli_mode}=    IT COMMON - Get Cli Field    ${cli}    Running Mode",
                        "Should Be Equal    ${cli_mode}    ${cli_mode_suffix}",
                        "${cli_stage}=    IT COMMON - Get Cli Field    ${cli}    Current Stage",
                        "Should Be Equal    ${cli_stage}    IDLE",
                        "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                        "IT COMMON - Grpc Should Succeed    ${response}",
                        "${status}=    IT COMMON - Grpc Get Field    ${response}    pabStatus",
                        "${mode}=    IT COMMON - Grpc Get Field    ${status}    runningMode",
                        "Should Be Equal    ${mode}    ALIGN_PAB_MODE_${mode_suffix}",
                    ]
                ),
                vars=[
                    ("mode_suffix", _mode),
                    ("cli_mode_suffix", _mode),
                ],
            ),
        ] + (
            [
                C(
                    "Wait for the PAB round to be over",
                    doc=[
                        "Step 1. Wait until the round is completed and the stage is IDLE",
                        "Step 2. Check the running status",
                    ],
                    tags=["CLI", "WRITE"],
                    log="3_cli.log",
                    body=[
                        # The template expects the running status to be
                        # CONTINUE_DELAY while the round runs. The stage 1 of a
                        # round still reads DONE, so the status is waited for.
                        "${delay}=    IT COMMON - Wait For Dut Cli Field    sc_cli get_pab_status    Running Status    CONTINUE_DELAY    timeout=120    interval=1",
                        "${delay_status}=    IT COMMON - Get Cli Field    ${delay}    Running Status",
                        "Should Be Equal    ${delay_status}    CONTINUE_DELAY",
                        "${fields}=    Create List    Running Mode=FREERUN    Completed=Yes    Current Stage=IDLE",
                        "${status}=    IT COMMON - Wait For Dut Cli Fields    sc_cli get_pab_status    ${fields}    timeout=300    interval=10",
                        "Log    ${status}",
                        "${running}=    IT COMMON - Get Cli Field    ${status}    Running Status",
                        "Should Be Equal    ${running}    DONE",
                    ],
                ),
            ]
            if _running
            else [
                C(
                    "Check that the PAB is at rest",
                    doc=[
                        "Step 1. GET the PAB status",
                        "Step 2. The stage has to be IDLE and the procedure has to be",
                        "        at rest",
                    ],
                    tags=["CLI", "WRITE"],
                    log="3_cli.log",
                    body=[
                        "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                        "${stage}=    IT COMMON - Get Cli Field    ${status}    Current Stage",
                        "Should Be Equal    ${stage}    IDLE",
                        # The Completed field is not checked: a round that the
                        # STOP cut short is not counted as completed, so the
                        # field depends on whether the PAB was running when the
                        # command arrived. The running status and the stage
                        # are the same either way.
                        "${running}=    IT COMMON - Get Cli Field    ${status}    Running Status",
                        "Should Be Equal    ${running}    DONE",
                    ],
                ),
            ]
        ),
    )

S(
    "PAB-016",
    sheet="PAB",
    area="FreeRun Boot-up",
    comment="Check that PAB runs in FreeRun mode after a factory default and a reboot",
    doc="After the factory default configuration is restored and the DUT is "
        "rebooted, PAB has to start automatically in FREERUN mode and keep "
        "running until the eCM comes online (User Guide 6.2, 10.3).",
    cases=[
        C(
            "Check that PAB is in FreeRun mode after the bring up",
            doc=[
                "Step 1. The DUT has been restored to the factory default and rebooted",
                "Step 2. GET the PAB status",
                "Step 3. Check that PAB is enabled and runs in FreeRun mode",
                "Step 4. Check that the eCM is operational",
            ],
            tags=["CLI"],
            log="1_sc_cli.log",
            body=[
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                "${enabled}=    IT COMMON - Get Cli Field    ${status}    Enabled",
                "Should Be Equal    ${enabled}    Yes",
                "${mode}=    IT COMMON - Get Cli Field    ${status}    Running Mode",
                "Should Be Equal    ${mode}    FREERUN",
                # The PAB keeps running until the eCM comes online, so the eCM
                # is waited for instead of being read once.
                "${ecm_status}=    IT COMMON - Wait For Dut Command Contains",
                "...    sc_amphal_cli get_ecm_status",
                "...    eCM status = Operational",
                "...    timeout=180    interval=10",
                "Log    ${ecm_status}",
            ],
        ),
        C(
            "Check the PAB configuration after the bring up",
            doc=[
                "Step 1. GET the PAB configuration",
                "Step 2. Check that the configuration is the factory default: the LNA",
                "        mode is FIXED_GAIN, the gain is 2.74 dBmV, the target TCP is",
                "        36.00 dBmV, the intervals are 60 sec and the thresholds are",
                "        -27.78 dBmV and 6.00",
            ],
            tags=["CLI"],
            log="2_sc_cli.log",
            body=[
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_config",
                "${mode}=    IT COMMON - Get Cli Field    ${config}    rx adc lna mode",
                "Should Be Equal    ${mode}    3 (FIXED_GAIN)",
                "${gain}=    IT COMMON - Get Cli Field    ${config}    rx adc lna gain",
                "Should Be Equal    ${gain}    2.74 dBmV",
                "${tcp}=    IT COMMON - Get Cli Field    ${config}    target tcp",
                "Should Be Equal    ${tcp}    36.00 dBmV",
                "${online}=    IT COMMON - Get Cli Field    ${config}    online interval",
                "Should Be Equal    ${online}    60 sec",
                "${retry}=    IT COMMON - Get Cli Field    ${config}    retry interval",
                "Should Be Equal    ${retry}    60 sec",
                "${rpd}=    IT COMMON - Get Cli Field    ${config}    RPD power threshold",
                "Should Be Equal    ${rpd}    -27.78 dBmV",
                "${outlier}=    IT COMMON - Get Cli Field    ${config}    outlier threshold",
                "Should Be Equal    ${outlier}    6.00",
            ],
        ),
    ],
)
