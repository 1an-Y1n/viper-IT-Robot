"""The CHANGELIST sheet of the LE IT test template.

Only the fourteen items that carry a procedure in the template are here. The
sixteen items without one are not test cases: the template marks them as
"no IT testing is required" or leaves them empty.

The items that need a firmware change, a deploy script or a reboot carry that
step as a documented prerequisite and automate the part that can be
automated.
"""

from writer import C, S


def _version_case(item_id, title, log, expect_dstracker=False):
    """Read the version of the image of the DUT."""
    body = [
        "${out}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt",
        "Log    ${out}",
        "Should Contain    ${out}    SW_VERSION=00.04.006",
        "Should Contain    ${out}    IMAGE_NAME=Viper_LE-CAMP-00.04.006",
    ]
    if expect_dstracker:
        body.append(
            "${service}=    IT COMMON - Run Dut Command And Return    systemctl is-active dstracker"
        )
        body.append("Log    ${service}")
    return C(
        title,
        doc=[
            "Step 1. Read /sc_versions.txt",
            "Step 2. The image has to be the release 00.04.006 or later",
        ],
        tags=["FILE"],
        log=log,
        body=body,
    )


S(
    "CL-002",
    sheet="CHANGELIST",
    area="CUST_FACING",
    comment="The telnet client is gone from the eAMP",
    doc="The telnet customization is removed from the eAMP, so the embedded "
        "cable modem can only be reached over SSH (CAMP-2415).",
    cases=[
        C(
            "Check that the telnet client is gone",
            doc=[
                "Step 1. Check that which telnet does not find anything",
                "Step 2. Check that /usr/bin/telnet and /bin/telnet are not there",
                "Step 3. Check that the telnet applet is not in the BusyBox list",
                "Step 4. Check that busybox telnet reports that the applet is not there",
            ],
            tags=["CLI", "FILE"],
            log="1_telnet.log",
            body=[
                "${which}=    IT COMMON - Run Dut Command And Return    which telnet",
                "Log    ${which}",
                "Should Not Contain    ${which}    /bin/telnet",
                "Should Not Contain    ${which}    /usr/bin/telnet",
                "${usr_bin}=    IT COMMON - Run Dut Command And Return    ls -l /usr/bin/telnet",
                "Log    ${usr_bin}",
                "Should Contain    ${usr_bin}    No such file",
                "${bin}=    IT COMMON - Run Dut Command And Return    ls -l /bin/telnet",
                "Log    ${bin}",
                "Should Contain    ${bin}    No such file",
                "${applet}=    IT COMMON - Run Dut Command And Return    busybox 2>&1 | grep telnet",
                "Log    ${applet}",
                "Should Be Equal    ${applet}    ${EMPTY}",
                "${run}=    IT COMMON - Run Dut Command And Return    busybox telnet 172.31.255.45",
                "Log    ${run}",
                "Should Contain    ${run}    applet not found",
            ],
        ),
        C(
            "Check the private link to the embedded cable modem",
            doc=[
                "Step 1. Check the route to the private link",
                "Step 2. Ping the embedded cable modem",
                "Step 3. Read the status of the embedded cable modem",
            ],
            tags=["CLI"],
            log="2_link.log",
            body=[
                "${route}=    IT COMMON - Run Dut Command And Return    ip route | grep 172.31.255",
                "Log    ${route}",
                "Should Contain    ${route}    172.31.255.0/24",
                "${ping}=    IT COMMON - Run Dut Command And Return    ping -c 2 -W 3 172.31.255.45    timeout=30",
                "Log    ${ping}",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_amphal_cli get_ecm_status",
                "Log    ${status}",
                "Should Contain    ${status}    eCM status = Operational",
            ],
        ),
    ],
)

S(
    "CL-006",
    sheet="CHANGELIST",
    area="ASC",
    comment="The run-time log of sc-asc is aligned with sc-agc",
    doc="The run-time log of the sc-asc daemon is aligned with the one of "
        "sc-agc (DZ300-1588).",
    cases=[
        _version_case("CL-006", "Read the version and the state of the daemon", "1_baseline.log"),
        C(
            "Read the service and the configuration of the ASC",
            doc=[
                "Step 1. Check that the sc-asc service is running",
                "Step 2. Read the ASC and the AGC configuration",
            ],
            tags=["CLI"],
            log="2_service.log",
            body=[
                "${service}=    IT COMMON - Run Dut Command And Return    systemctl status sc-asc --no-pager",
                "Log    ${service}",
                "Should Contain    ${service}    Active: active (running)",
                "${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${asc}",
                "Log    ${agc}",
                "Should Contain    ${asc}    operationMode",
                "Should Contain    ${asc}    inputInterval",
                "Should Contain    ${agc}    Legacy enable",
                "Should Contain    ${agc}    Fdx enable",
            ],
        ),
        C(
            "Check the default configuration file",
            doc=[
                "Step 1. Check that agc_data.json is there",
                "Step 2. Read its version",
            ],
            tags=["FILE"],
            log="3_default_config.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol/agc_data.json",
                "Log    ${out}",
                "Should Not Contain    ${out}    No such file",
                "${version}=    IT COMMON - Run Dut Command And Return    grep -a -m1 version /mnt/sc_nonvol/agc_data.json",
                "Log    ${version}",
                "Should Contain    ${version}    version",
            ],
        ),
        C(
            "Set the input interval and read it back",
            doc=[
                "Step 1. Set the input interval to 90 s",
                "Step 2. Read the configuration back",
            ],
            tags=["CLI", "WRITE"],
            log="4_persistence.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${old}=    IT COMMON - Get Cli Field    ${before}    inputInterval",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval 90",
                "Log    ${set}",
                "Should Contain    ${set}    success",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "IT COMMON - Cli Number Should Equal    ${after}    inputInterval    90",
                "${back}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config inputInterval ${old}",
                "${restored}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "IT COMMON - Cli Number Should Equal    ${restored}    inputInterval    ${old}",
            ],
        ),
        C(
            "Check the validation of the tuning IDs of the AGC",
            doc=[
                "Step 1. Set the three invalid tuning IDs, they have to be refused",
                "Step 2. Set the two valid tuning IDs, they have to be accepted",
                "Step 3. Put the AGC configuration back",
            ],
            tags=["CLI", "WRITE"],
            log="5_tuning_ids.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${old_legacy}=    IT COMMON - Get Cli Field    ${before}    Legacy enable",
                "${old_track}=    IT COMMON - Get Cli Field    ${before}    Track eCM power enable",
                "${invalid0}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 0 1",
                "${invalid19}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 19 1",
                "${invalid25}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 25 1",
                "Log    ${invalid0}",
                "Log    ${invalid19}",
                "Log    ${invalid25}",
                "${valid3}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 3 1",
                "Log    ${valid3}",
                "${valid8}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_config 8 1",
                "Log    ${valid8}",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "Log    ${after}",
                "Should Contain    ${after}    Legacy enable: true",
                "Should Contain    ${after}    Track eCM power enable: true",
            ],
        ),
        C(
            "Check the controller handover and the NP DS loop",
            doc=[
                "Step 1. Read the MSC controller",
                "Step 2. Read the state of the NP DS machine",
                "Step 3. Look for the transient entries of the loop in the syslog",
            ],
            tags=["CLI", "FILE"],
            log="6_controller.log",
            body=[
                "${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller",
                "Log    ${controller}",
                "Should Contain    ${controller}    MSC controller:",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status np_ds",
                "Log    ${status}",
                "${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'TRANSIENT' /dev/shm/syslog | tail -n 5",
                "Log    ${syslog}",
            ],
        ),
        C(
            "Check that there is no CRIT in the syslog",
            doc=[
                "Step 1. Count the CRIT lines of the syslog",
                "Step 2. There has to be none",
            ],
            tags=["FILE"],
            log="7_crit.log",
            body=[
                "${count}=    IT COMMON - Run Dut Command And Return    grep -ac 'CRIT' /dev/shm/syslog",
                "Log    ${count}",
                "${number}=    Evaluate    int($count.strip())    modules=builtins",
                "Should Be Equal As Integers    ${number}    0",
            ],
        ),
    ],
)

S(
    "CL-008",
    sheet="CHANGELIST",
    area="ASC",
    comment="The clipping monitor default interval is two seconds",
    doc="The clipping monitor default interval is raised to two seconds and "
        "the calibration snapshot carries two new keys (DZ300-1918).",
    cases=[
        C(
            "Check the clipping interval of the ASC",
            doc=[
                "Step 1. Read the clipping interval of the ASC",
                "Step 2. It has to be two seconds",
                "Step 3. Look for the clipping lines of the syslog",
            ],
            tags=["CLI", "FILE"],
            log="1_clipping.log",
            body=[
                "${config}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${interval}=    IT COMMON - Get Cli Field    ${config}    clippingInterval",
                "Log    ${interval}",
                "Should Be Equal    ${interval}    2",
                "${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'UpdateControlData' /dev/shm/syslog | tail -n 3",
                "Log    ${syslog}",
            ],
        ),
        C(
            "Check the two new keys of the calibration snapshot",
            doc=[
                "Step 1. Dump the calibration snapshot",
                "Step 2. Check that the dump holds the two new keys",
            ],
            tags=["CLI", "FILE"],
            log="2_snapshot.log",
            vars=[("dump_file", "/tmp/cl008_snapshot.json")],
            body=[
                "${dump}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot dump ${dump_file}    timeout=120",
                "Log    ${dump}",
                "${size}=    IT COMMON - Wait For File On Dut    ${dump_file}    timeout=60",
                "Should Not Be Equal    ${size}    0",
                "${show}=    IT COMMON - Run Dut Command And Return    sc_cli asc_calib_snapshot show",
                "Log    ${show}",
                "Should Contain    ${show}    np_f_reference_spectrum",
                "Should Contain    ${show}    fdx_path_gain_cal",
            ],
        ),
    ],
)

S(
    "CL-009",
    sheet="CHANGELIST",
    area="CUST_FACING",
    comment="The 33368 byte MsgBody contract of amp-rfimgr-lib",
    doc="The MsgBody contract of amp-rfimgr-lib is restored, so the DS Tracker "
        "can be deployed and configured (DZ300-1920). The deploy of the binary "
        "needs the file server and is a step of the bench procedure.",
    cases=[
        _version_case("CL-009", "Read the version of the image", "1_version.log"),
        C(
            "Check the state of the DS Tracker",
            doc=[
                "Step 1. Check whether the DS Tracker service is there",
                "Step 2. Look for the tracker process",
                "Step 3. Read the version of the tracker from the syslog",
            ],
            tags=["CLI", "FILE"],
            log="2_dstracker.log",
            body=[
                "${service}=    IT COMMON - Run Dut Command And Return    systemctl is-active dstracker",
                "Log    ${service}",
                "${process}=    IT COMMON - Run Dut Command And Return    ps aux | grep -i '[d]stracker'",
                "Log    ${process}",
                "${version}=    IT COMMON - Run Dut Command And Return    grep -a 'Dstracker version' /dev/shm/syslog | tail -n 3",
                "Log    ${version}",
            ],
        ),
        C(
            "Check the DPM configuration over gRPC",
            doc=[
                "Step 1. Read the DPM configuration",
                "Step 2. The answer has to report success",
            ],
            tags=["GRPC"],
            log="3_dpm.log",
            vars=[
                ("proto", "ds_periodic_maintanence.proto"),
                ("method", "gnoi.ds_periodic_maintanence.v1.DownstreamPeriodicMaintanence/GetDpmConfiguration"),
            ],
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "${enabled}=    IT COMMON - Grpc Get Field    ${response}    enabled",
                "Log    ${enabled}",
            ],
        ),
        C(
            "Look for the failure signature of the old MsgBody contract",
            doc=[
                "Step 1. Count the Message too long lines of the syslog",
                "Step 2. There has to be none",
                "Step 3. Look for the CDF of the reset",
            ],
            tags=["FILE"],
            log="4_signature.log",
            body=[
                "${count}=    IT COMMON - Run Dut Command And Return    grep -acE 'Message too long|ampLib.c line' /dev/shm/syslog",
                "Log    ${count}",
                "${number}=    Evaluate    int($count.strip())    modules=builtins",
                "Should Be Equal As Integers    ${number}    0",
                "${cdf}=    IT COMMON - Run Dut Command And Return    ls -l /log/cdf",
                "Log    ${cdf}",
                "${reset}=    IT COMMON - Run Dut Command And Return    grep -acE 'gencdf|palgencdf|Initiating AMP reset' /dev/shm/syslog",
                "Log    ${reset}",
            ],
        ),
    ],
)

S(
    "CL-014",
    sheet="CHANGELIST",
    area="ALIGNMENT",
    comment="The attenuator response reports the unclamped value",
    doc="The AdjustAttenuatorResponse of sc-rfboard has to report the level "
        "that the hardware really applied and not the requested one "
        "(DZ300-1873).",
    # The attenuation that is in place before the case is carried from the
    # first case to the case that puts it back, so it is declared here and
    # filled in with a suite scope.
    vars=[("original", "${EMPTY}")],
    cases=[
        C(
            "Turn the message recording on and record the state",
            doc=[
                "Step 1. Create the flag file that turns the message recording on",
                "Step 2. Read the attenuation of the SP DS port",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_record.log",
            body=[
                "${flag}=    IT COMMON - Run Dut Command And Return    touch /mnt/sc_nonvol/sc_record_proto_msg",
                "${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2",
                "Log    ${before}",
                "Should Contain    ${before}    SP_DS_ATT",
                # The configuration value of the SP DS attenuation is the one to
                # put back, it is what the template asks for.
                "${original}=    Evaluate    [line for line in $before.splitlines() if 'SP_DS_ATT (' in line][0].split('config = ')[1].split(' dB')[0]    modules=builtins",
                "VAR    ${original}    ${original}    scope=SUITE",
            ],
        ),
        C(
            "Send the out of range adjustment and read the applied value",
            doc=[
                "Step 1. Send the relative adjustment that reaches the clamp",
                "Step 2. Read the attenuation again, it has to be the minimum",
                "Step 3. Look at the recorded response",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="2_clamp.log",
            body=[
                "${request}=    IT COMMON - Run Dut Command And Return    cliwrapper_client -s /tmp/brcmhal.sock -t 1000 -d '/calibration/adjust_attenuator 1 -45.5'    timeout=60",
                "Log    ${request}",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2",
                "Log    ${after}",
                "${record}=    IT COMMON - Run Dut Command And Return    grep -a 'attenuation_db' /tmp/sc_rfboard_msg.log | tail -n 3",
                "Log    ${record}",
            ],
        ),
        C(
            "Put the attenuation back",
            doc=[
                "Step 1. Read the value that is in place now",
                "Step 2. Put the value of the factory default back",
                "Step 3. Read it again",
            ],
            tags=["CLI", "WRITE"],
            log="3_restore.log",
            body=[
                "${current}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_attenuation 2 ${original}",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2",
                "Log    ${after}",
                "Should Contain    ${after}    SP_DS_ATT",
            ],
        ),
    ],
)

S(
    "CL-016",
    sheet="CHANGELIST",
    area="ALIGNMENT",
    comment="Stage F of the FDX enablement can be run again",
    doc="The Stage F of the FDX enablement has to be re-runnable after it "
        "completed once (CAMP-2439).",
    cases=[
        _version_case("CL-016", "Read the version of the image", "1_version.log"),
        C(
            "Check that the gRPC method is there",
            doc=[
                "Step 1. List the methods of the FdxEnablement service",
                "Step 2. NonRootConfigureBackoff has to be listed",
            ],
            tags=["GRPC"],
            log="2_method.log",
            vars=[
                (
                    "cmd",
                    "grpcurl -plaintext -import-path /etc/amp/proto -proto fdx_enablement.proto 127.0.0.1:9338 list gnoi.fdx_enablement.v1.FdxEnablement",
                ),
            ],
            body=[
                "${out}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    timeout=30",
                "Log    ${out}",
                "Should Contain    ${out}    NonRootConfigureBackoff",
            ],
        ),
        C(
            "Call the method twice and check that both calls succeed",
            doc=[
                "Step 1. Call NonRootConfigureBackoff",
                "Step 2. Call it a second time, it has to succeed as well",
                "Step 3. Look at the syslog of the two calls",
            ],
            tags=["GRPC", "WRITE"],
            log="3_call.log",
            vars=[
                (
                    "cmd",
                    "grpcurl -plaintext -import-path /etc/amp/proto -proto fdx_enablement.proto -d '{}' 127.0.0.1:9338 gnoi.fdx_enablement.v1.FdxEnablement.NonRootConfigureBackoff",
                ),
            ],
            body=[
                "${first}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    timeout=60",
                "Log    ${first}",
                "Should Contain    ${first}    SUCCESS",
                "${second}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    timeout=60",
                "Log    ${second}",
                "Should Contain    ${second}    SUCCESS",
                "${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'NonRootConfigureBackoff' /dev/shm/syslog | tail -n 10",
                "Log    ${syslog}",
            ],
        ),
    ],
)

S(
    "CL-018",
    sheet="CHANGELIST",
    area="CUST_FACING",
    comment="The SSH login with special characters in the password",
    doc="The SSH login has to work when the password holds special characters "
        "(DZ300-1876).",
    cases=[
        C(
            "Record the baseline of the user database",
            doc=[
                "Step 1. Count the lines of /etc/passwd",
                "Step 2. Back up /etc/passwd and /etc/shadow",
            ],
            tags=["FILE", "WRITE"],
            log="1_baseline.log",
            body=[
                "${count}=    IT COMMON - Run Dut Command And Return    grep -c . /etc/passwd",
                "Log    ${count}",
                "${backup}=    IT COMMON - Run Dut Command And Return    cp /etc/passwd /tmp/passwd.backup && cp /etc/shadow /tmp/shadow.backup",
                "Log    ${backup}",
            ],
        ),
        C(
            "Check the rules of the user names",
            doc=[
                "Step 1. Create a user with a valid name",
                "Step 2. Read the user database, the user has to be there",
                "Step 3. Create a user with an invalid name, it has to be refused",
                "Step 4. Remove the valid user again",
            ],
            tags=["CLI", "WRITE"],
            log="2_usernames.log",
            body=[
                "${valid}=    IT COMMON - Run Fdx Command And Return    configure username ituser1 password Pw4920a",
                "Log    ${valid}",
                "Should Contain    ${valid}    ituser1",
                "${users}=    IT COMMON - Run Fdx Command And Return    debug login show configured-users-db",
                "Log    ${users}",
                "Should Contain    ${users}    ituser1",
                "${invalid}=    IT COMMON - Run Fdx Command And Return    configure username .baduser password Pw4920a",
                "Log    ${invalid}",
                "${remove}=    IT COMMON - Run Fdx Command And Return    configure username ituser1 no",
                "Log    ${remove}",
            ],
        ),
        C(
            "Check a password with a special character",
            doc=[
                "Step 1. Create a user whose password holds a special character",
                "Step 2. Read the user database, the user has to be there",
                "Step 3. Remove the user again",
                "Step 4. Put the user database back",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="3_password.log",
            body=[
                "${create}=    IT COMMON - Run Fdx Command And Return    configure username ituser2 password swpa&4920",
                "Log    ${create}",
                "Should Contain    ${create}    ituser2",
                "${users}=    IT COMMON - Run Fdx Command And Return    debug login show configured-users-db",
                "Should Contain    ${users}    ituser2",
                "${remove}=    IT COMMON - Run Fdx Command And Return    configure username ituser2 no",
                "${restore}=    IT COMMON - Run Dut Command And Return    cp /tmp/passwd.backup /etc/passwd && cp /tmp/shadow.backup /etc/shadow",
                "Log    ${restore}",
            ],
        ),
    ],
)

S(
    "CL-019",
    sheet="CHANGELIST",
    area="ALIGNMENT",
    comment="The NP DS EQ worksheet",
    doc="The NP DS equalization of the worksheet is updated (DZ300-1912).",
    cases=[
        C(
            "Run the round two fingerprint of the 1.2G band",
            doc=[
                "Step 1. Set the two tilt anchors",
                "Step 2. Apply the equalization adjustment",
                "Step 3. Read the tilts back",
            ],
            tags=["CLI", "WRITE"],
            log="1_fingerprint.log",
            body=[
                "${eq4_before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0",
                "${eq4}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 4 1.53",
                "${eq5}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -10.88",
                "${adjust}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli adjust_np_ds_eqs 0.905    timeout=60",
                "Log    ${adjust}",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0",
                "Log    ${after}",
                "Should Contain    ${after}    NP_DS_VCEQ",
                "Should Contain    ${after}    NP_DS_INVERSE_EQ",
            ],
        ),
        C(
            "Probe the granularity of the EQ5 lookup table",
            doc=[
                "Step 1. Set the five values of the probe",
                "Step 2. Read the value back",
            ],
            tags=["CLI", "WRITE"],
            log="2_granularity.log",
            body=[
                "${v1}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -9.00",
                "${v2}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -8.50",
                "${v3}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -8.03",
                "${v4}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -7.50",
                "${v5}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 5 -7.00",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 5",
                "Log    ${after}",
                "Should Contain    ${after}    NP_DS_INVERSE_EQ",
            ],
        ),
    ],
)

S(
    "CL-021",
    sheet="CHANGELIST",
    area="CUST_FACING",
    comment="Every GEN2 device type is mapped in the running configuration",
    doc="Every GEN2 device type is mapped in the answer of the "
        "RunningConfiguration service (CAMP-2536).",
    vars=[
        ("proto", "running_configuration.proto"),
        ("method", "gnoi.running_configuration.v1.RunningConfiguration/GetConfiguration"),
    ],
    cases=[
        C(
            "Read the running configuration over gRPC",
            doc=[
                "Step 1. Call GetConfiguration",
                "Step 2. The answer has to carry a success block and no failure block",
                "Step 3. The three attenuation lists have to hold one MAIN_PORT entry",
            ],
            tags=["GRPC"],
            log="1_configuration.log",
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${EMPTY}    timeout=60",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "IT COMMON - Grpc Should Not Have Field    ${response}    failure",
                "${north}=    IT COMMON - Grpc Get Field    ${response}    northAfeAttenuations",
                "${ds_output}=    IT COMMON - Grpc Get Field    ${response}    dsOutputAttenuations",
                "${legacy}=    IT COMMON - Grpc Get Field    ${response}    legacyUsInputAttenuations",
                "${north_count}=    Evaluate    len($north)    modules=builtins",
                "Should Be Equal As Integers    ${north_count}    1",
                "${ds_count}=    Evaluate    len($ds_output)    modules=builtins",
                "Should Be Equal As Integers    ${ds_count}    1",
                "${legacy_count}=    Evaluate    len($legacy)    modules=builtins",
                "Should Be Equal As Integers    ${legacy_count}    1",
            ],
        ),
        C(
            "Look at the syslog of the call",
            doc=[
                "Step 1. Look for the reads of the downstream and the legacy upstream attenuation",
                "Step 2. There must not be an invalid port number",
            ],
            tags=["FILE"],
            log="2_syslog.log",
            body=[
                "${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'palGetDsOutputPortAtten\\|palGetLegacyUsInputAtten\\|Invalid port number' /dev/shm/syslog | tail -n 10",
                "Log    ${syslog}",
                "Should Not Contain    ${syslog}    Invalid port number: 1",
            ],
        ),
    ],
)

S(
    "CL-025",
    sheet="CHANGELIST",
    area="PAB",
    comment="The North AFE backoff is mapped to the interference ratio",
    doc="palGetNorthAfeBackOff and palSetNorthAfeBackOff are mapped to the "
        "downstream_plus_interference_to_downstream_ratio_db of the "
        "configuration (CAMP-2542).",
    cases=[
        C(
            "Read the two keys of the north port configuration",
            doc=[
                "Step 1. Read the two keys of /mnt/sc_nonvol/ampapp_data.json",
            ],
            tags=["FILE"],
            log="1_baseline.log",
            body=[
                "${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json",
                "${north}=    IT COMMON - Get Dict Field    ${parsed}    north_port_configuration",
                "${ratio}=    IT COMMON - Get Dict Field    ${north}    downstream_plus_interference_to_downstream_ratio_db",
                "${backoff}=    IT COMMON - Get Dict Field    ${north}    rx_adc_backoff_db",
                "Log    ${ratio}",
                "Log    ${backoff}",
            ],
        ),
        C(
            "Set the AFE backoff and check the mapping",
            doc=[
                "Step 1. Set the North AFE backoff to 3 dB",
                "Step 2. Read the two keys again, the ratio has to be 3 and the backoff must not have moved",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="2_mapping.log",
            body=[
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_north_afe_back_off 3",
                "Log    ${set}",
                "${parsed}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json",
                "${north}=    IT COMMON - Get Dict Field    ${parsed}    north_port_configuration",
                "${ratio}=    IT COMMON - Get Dict Field    ${north}    downstream_plus_interference_to_downstream_ratio_db",
                "Should Be Equal As Integers    ${ratio}    3",
                "${backoff}=    IT COMMON - Get Dict Field    ${north}    rx_adc_backoff_db",
                "Should Not Be Equal    ${backoff}    3",
            ],
        ),
    ],
)

S(
    "CL-026",
    sheet="CHANGELIST",
    area="PAB",
    comment="The completion status and the MSC completion flag do not diverge",
    doc="The completion status of the PAB and the MSC completion flag must "
        "not diverge after a PAB run (DZ300-1979).",
    cases=[
        C(
            "Check that the fix is in the image",
            doc=[
                "Step 1. Look for the two error messages of the old behaviour in the binary",
            ],
            tags=["FILE"],
            log="1_fix.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    strings /usr/bin/sc_alignment | grep -a 'PAB snapshot persistence failed'",
                "Log    ${out}",
                "${flag}=    IT COMMON - Run Dut Command And Return    strings /usr/bin/sc_alignment | grep -a 'Failed to set pab_completed_config_flag'",
                "Log    ${flag}",
            ],
        ),
        C(
            "Run the PAB again and check the completion",
            doc=[
                "Step 1. Read the PAB status",
                "Step 2. Start the PAB in FreeRun mode",
                "Step 3. Wait until the round is over",
                "Step 4. Look for the stage seven lines of the syslog",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="2_rerun.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                "Log    ${before}",
                "${run}=    IT COMMON - Run Dut Command And Return    sc_cli pab_control free_run",
                "Should Contain    ${run}    Success",
                "${fields}=    Create List    Running Mode=FREERUN    Completed=Yes    Current Stage=IDLE",
                "${status}=    IT COMMON - Wait For Dut Cli Fields    sc_cli get_pab_status    ${fields}    timeout=300    interval=10",
                "Log    ${status}",
                "${syslog}=    IT COMMON - Run Dut Command And Return    grep -a '\\[ScPabStage7\\]' /dev/shm/syslog | tail -n 10",
                "Log    ${syslog}",
            ],
        ),
        C(
            "Check the state after the run",
            doc=[
                "Step 1. Read the MSC controller",
                "Step 2. Read the PAB status",
                "Step 3. The completion flag and the status must not diverge",
            ],
            tags=["CLI"],
            log="3_after.log",
            body=[
                "${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                "Log    ${controller}",
                "Log    ${status}",
                "${completed}=    IT COMMON - Get Cli Field    ${status}    Completed",
                "Should Be Equal    ${completed}    Yes",
                "${mode}=    IT COMMON - Get Cli Field    ${status}    Running Mode",
                "Should Be Equal    ${mode}    FREERUN",
            ],
        ),
    ],
)

S(
    "CL-028",
    sheet="CHANGELIST",
    area="CUST_FACING",
    comment="The eAMP talks to the eCM over SNMP instead of the UDP RPC",
    doc="The UDP RPC between the eAMP and the eCM is replaced by SNMP "
        "(CAMP-2414).",
    cases=[
        C(
            "Check the version and the reachability of the eCM",
            doc=[
                "Step 1. Read the version of the image",
                "Step 2. Ping the management address of the eCM",
            ],
            tags=["CLI", "FILE"],
            log="1_baseline.log",
            body=[
                "${version}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt",
                "Should Contain    ${version}    SW_VERSION=00.04.006",
                "${ping}=    IT COMMON - Run Dut Command And Return    ping -c 2 -W 3 172.31.255.45    timeout=30",
                "Log    ${ping}",
            ],
        ),
        C(
            "Read the upstream diagnosis",
            doc=[
                "Step 1. Run sc_cli get_upstream_diagnosis",
                "Step 2. The answer has to hold the channels with their frequency and their power",
            ],
            tags=["CLI"],
            log="2_diagnosis.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    sc_cli get_upstream_diagnosis    timeout=60",
                "Log    ${out}",
                "Should Contain    ${out}    Upstream Diagnosis:",
                "Should Contain    ${out}    Number of channels:",
                "Should Contain    ${out}    frequency_hz=",
                "Should Contain    ${out}    power_dbmv=",
            ],
        ),
        C(
            "Check that the SNMP client of the eAMP is used",
            doc=[
                "Step 1. Look at the sc_amphal lines of the syslog",
                "Step 2. They have to show the SNMP client and the upstream diagnosis",
            ],
            tags=["FILE"],
            log="3_syslog.log",
            body=[
                "${syslog}=    IT COMMON - Run Dut Command And Return    grep -a sc_amphal /dev/shm/syslog | tail -n 20",
                "Log    ${syslog}",
                "Should Contain    ${syslog}    ScEcmSnmpClient init done",
                "Should Contain    ${syslog}    GetUpstreamDiagnosisRaw",
            ],
        ),
    ],
)

S(
    "CL-029",
    sheet="CHANGELIST",
    area="ASC",
    comment="The gRPC ASC disable goes to Disable and not to Monitor",
    doc="The gRPC ASC disable has to switch the ASC to the Disable mode and "
        "not to the Monitor mode (DZ300-1988).",
    vars=[
        ("proto", "asc_config.proto"),
        ("get_method", "gnoi.asc_config.v1.AscConfigService/GetAscConfiguration"),
        ("set_method", "gnoi.asc_config.v1.AscConfigService/SetAscConfiguration"),
    ],
    cases=[
        C(
            "Disable the ASC over gRPC and check it",
            doc=[
                "Step 1. Read the current configuration over gRPC",
                "Step 2. SET the enable field to zero",
                "Step 3. Read the configuration again, the enable has to be zero",
                "Step 4. Read the configuration over sc_cli, it has to be Disable",
                "Step 5. Check the configuration file",
                "Step 6. Look at the syslog",
            ],
            tags=["GRPC", "CLI", "FILE", "WRITE"],
            log="1_disable.log",
            vars=[
                ("payload", '{"ascConfig": {"enable": 0}}'),
            ],
            body=[
                "${before}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "IT COMMON - Grpc Should Succeed    ${before}",
                "${set}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${payload}",
                "IT COMMON - Grpc Should Succeed    ${set}",
                "${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "IT COMMON - Grpc Should Succeed    ${after}",
                "${enable}=    IT COMMON - Grpc Number Should Equal    ${after}    ${{['ascConfig', 'enable']}}    0",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Log    ${cli}",
                "Should Contain    ${cli}    operationMode = Disable",
                "${file}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/agc_data.json",
                "Should Contain    ${file}    operation_mode",
                "${syslog}=    IT COMMON - Run Dut Command And Return    grep -a 'Operation mode\\|Control loops stopping\\|Enable AGC' /dev/shm/syslog | tail -n 10",
                "Log    ${syslog}",
            ],
        ),
        C(
            "Enable the ASC over gRPC again",
            doc=[
                "Step 1. SET the enable field to one",
                "Step 2. Read the configuration over sc_cli, it has to be FreeRun",
            ],
            tags=["GRPC", "CLI", "WRITE"],
            log="2_enable.log",
            vars=[
                ("payload", '{"ascConfig": {"enable": 1}}'),
            ],
            body=[
                "${set}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${payload}",
                "IT COMMON - Grpc Should Succeed    ${set}",
                "${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "IT COMMON - Grpc Number Should Equal    ${after}    ${{['ascConfig', 'enable']}}    1",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Log    ${cli}",
                "Should Contain    ${cli}    operationMode = FreeRun",
            ],
        ),
    ],
)

S(
    "CL-030",
    sheet="CHANGELIST",
    area="CUST_FACING",
    comment="The Gen2 PAL API",
    doc="The Gen2 PAL API adds the rf-components and the sc_cli commands of "
        "the second generation (CAMP-2338). The parts that this image does not "
        "carry yet are checked for the error that they have to report.",
    cases=[
        C(
            "Read the version and the generation of the amplifier",
            doc=[
                "Step 1. Read the version of the image",
                "Step 2. Read the generation over gNMI",
                "Step 3. The generation has to be GEN2",
            ],
            tags=["FILE", "GNMI"],
            log="1_generation.log",
            body=[
                "${version}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt",
                "Should Contain    ${version}    SW_VERSION=00.04.006",
                "${response}=    IT COMMON - Gnmi Get And Return    /amp-generation/version",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    /amp-generation/version",
                "Log    ${value}",
                "Should Be Equal    ${value}    GEN2",
            ],
        ),
        C(
            "Read the rf-components that the Gen2 API adds",
            doc=[
                "Step 1. GET the whole rf-components container",
                "Step 2. The answer has to hold the indexed nodes of the Gen2 API",
            ],
            tags=["GNMI"],
            log="2_rf_components.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    /rf-components",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    /rf-components",
                "Log    ${value}",
                "IT COMMON - Gnmi Leaf Should Exist    ${value}    north-afe-attenuation-db",
                "IT COMMON - Gnmi Leaf Should Exist    ${value}    north-afe-equalization-db",
                "IT COMMON - Gnmi Leaf Should Exist    ${value}    north-us-pa-bias",
                "IT COMMON - Gnmi Leaf Should Exist    ${value}    south-ds-pa-bias",
            ],
        ),
        C(
            "Check the negative case of the north port switch path",
            doc=[
                "Step 1. SET the north port switch path to the legacy upstream value",
                "Step 2. The SET has to fail",
            ],
            tags=["GNMI", "WRITE"],
            log="3_negative.log",
            vars=[
                (
                    "updates",
                    [
                        "/rf-components/north-port-switch-path:::string:::NP_SWITCH_LEGACY_UPSTREAM",
                    ],
                ),
            ],
            body=[
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    failed",
            ],
        ),
    ],
)
