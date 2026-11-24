"""The CUST_FACING sheet of the LE IT test template: CF-001 to CF-033.

The second half of the sheet (CF-034 to CF-061) is in sheet_cust_facing2.py.

The cases that need the bench or that would take the bench away (a firmware
upgrade, a reboot, a factory default, the management IP, the SSH
authentication settings) carry the step as a documented prerequisite and
automate the part that can be automated.
"""

from writer import C, S

SANITY = "Sanity Check"
BASIC = "System & Basic Configuration"
COMCAST_CLI = "Comcast CLI"
SERCOMM_CLI = "Sercomm CLI"
FW_SPECTRUM = "DS Output Spectrum Before and After FW Upgrade"
LEDS = "LED Tests"


def _file_case(item_id, title, path, log, size_check=True):
    """Check that a file of the DUT is there."""
    body = [
        "${out}=    IT COMMON - Run Dut Command And Return    ls -l %s" % path,
        "Log    ${out}",
        "Should Not Contain    ${out}    No such file",
    ]
    if size_check:
        body.append("${size}=    IT COMMON - Wait For File On Dut    %s    timeout=60" % path)
        body.append("Should Not Be Equal    ${size}    0")
    return C(
        title,
        doc=[
            "Step 1. Check that %s is there" % path,
        ],
        tags=["FILE"],
        log=log,
        body=body,
    )


S(
    "CF-001",
    sheet="CUST_FACING",
    area=SANITY,
    comment="Run the sanity check script of the DUT",
    doc="Run the sanity check script that ships with the firmware and check "
        "that every check passes (User Guide 10.1).",
    cases=[
        C(
            "Run the sanity check script",
            doc=[
                "Step 1. Run /usr/bin/amp-gnmi-check.sh",
                "Step 2. Check that every check of the script passed",
            ],
            tags=["FILE"],
            log="1_sanity.log",
            body=[
                # The script checks the alignment status, so the DUT has to be
                # settled: an alignment that is still running reports
                # ALIGN_STATUS_IN_PROGRESS and the check of the script fails.
                "${idle}=    IT COMMON - Wait For No Gnmi Instance With    amp-alignment[alignment-type=*]    alignment-status    ALIGN_STATUS_IN_PROGRESS    timeout=300",
                "${out}=    IT COMMON - Run Dut Command And Return    /usr/bin/amp-gnmi-check.sh    timeout=600",
                "Log    ${out}",
                "Should Not Be Equal    ${out}    ${EMPTY}",
                # The script ends with a summary that counts the checks, e.g.
                # "Total: 12; Run: 12; Passed: 12; Failed: 0". The checks that
                # failed are named first, so the report says which ones they
                # are and not only how many there are.
                "${failed}=    Evaluate    [line for line in $out.splitlines() if '[FAIL]' in line]    modules=builtins",
                "IF    $failed",
                "    Fail    The sanity check of the DUT reports failed checks: ${failed}",
                "END",
                "Should Contain    ${out}    Failed: 0",
            ],
        ),
    ],
)

S(
    "CF-002",
    sheet="CUST_FACING",
    area=BASIC,
    comment="Check the login and the prompts of the three shells",
    doc="Check that the tester can log in with the default account and that "
        "the expected prompts are seen (User Guide 1.1).",
    cases=[
        C(
            "Check the clish prompt",
            doc=[
                "Step 1. Run a command on the clish shell",
                "Step 2. The buffer has to carry the clish prompt",
            ],
            tags=["CLI"],
            log="1_clish_prompt.log",
            body=[
                "${buffer}=    IT COMMON - Run Fdx Command And Return Raw    show version",
                "Should Contain    ${buffer}    FDX-AMP>$",
            ],
        ),
        C(
            "Check the linux shell prompt",
            doc=[
                "Step 1. Run a command on the linux shell",
                "Step 2. The buffer has to carry the linux prompt",
            ],
            tags=["CLI"],
            log="2_linux_prompt.log",
            body=[
                "${buffer}=    IT COMMON - Run Dut Command And Return Raw    uname -a",
                "Should Contain    ${buffer}    bash-3.2#",
            ],
        ),
        C(
            "Check the Broadcom HAL prompt",
            doc=[
                "Step 1. Enter the HAL from the clish shell",
                "Step 2. The buffer has to carry the HAL prompt",
                "Step 3. Leave the HAL again",
            ],
            tags=["CLI"],
            log="3_hal_prompt.log",
            body=[
                # The Broadcom CLI wrapper of this unit connects but does not
                # answer with its prompt, so the buffer is read without waiting
                # for the prompt: it is the only evidence of what the DUT did.
                "${buffer}=    IT COMMON - Run Fdx Command And Return Buffer    debug hal    timeout=15    prompt=hal>",
                "Log    ${buffer}",
                "Should Contain    ${buffer}    Connected.",
                "Should Contain    ${buffer}    hal>",
                "${out}=    IT COMMON - Run Fdx Command And Return Raw    \\x04    prompt=FDX-AMP>$",
                "Should Contain    ${out}    FDX-AMP>$",
            ],
        ),
        C(
            "Check the three Broadcom CLI wrappers",
            doc=[
                "Step 1. Check that the three sockets of the Broadcom CLI wrappers are there",
            ],
            tags=["FILE"],
            log="4_cliwrapper.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    ls -l /tmp/brcmsystem.sock /tmp/brcmhal.sock /tmp/brcmupgrade.sock",
                "Log    ${out}",
                "Should Not Contain    ${out}    No such file",
            ],
        ),
    ],
)

S(
    "CF-003",
    sheet="CUST_FACING",
    area=BASIC,
    comment="Check that the configuration files were migrated",
    doc="After a firmware update the configuration file has to be updated "
        "according to the latest default configuration (User Guide 10.4).",
    cases=[
        C(
            "Compare the RF board configuration with its default",
            doc=[
                "Step 1. Read /mnt/sc_nonvol/rfboard_data.json",
                "Step 2. Read /mnt/sc_nonvol/rfboard_data.json.default",
                "Step 3. Both have to carry the same version",
            ],
            tags=["FILE"],
            log="1_rfboard_data.log",
            body=[
                "${current_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/rfboard_data.json",
                "${default_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/rfboard_data.json.default",
                "${current_version}=    Evaluate    $current_json.get('version')    modules=builtins",
                "${default_version}=    Evaluate    $default_json.get('version')    modules=builtins",
                "Should Be Equal    ${current_version}    ${default_version}",
            ],
        ),
        C(
            "Compare the AMP application configuration with its default",
            doc=[
                "Step 1. Read /mnt/sc_nonvol/ampapp_data.json",
                "Step 2. Read the default of the AMP application configuration",
                "Step 3. Both have to carry the same version",
            ],
            tags=["FILE"],
            log="2_ampapp_data.log",
            body=[
                "${current_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json",
                "${current_version}=    Evaluate    $current_json.get('version')    modules=builtins",
                "${out}=    IT COMMON - Run Dut Command And Return    ls -l /card0/amp/ampapp_data.json.default",
                "Log    ${out}",
                "Should Not Contain    ${out}    No such file",
            ],
        ),
    ],
)

S(
    "CF-004",
    bench=True,
    sheet="CUST_FACING",
    area=BASIC,
    comment="Restore the factory default and check what is left in sc_nonvol",
    doc="After a factory default only s2p_files and s2pm5d may be left in "
        "sc_nonvol, and the system has to be able to complete its init after a "
        "reboot (User Guide 10.3). The case wipes the configuration of the DUT, "
        "so it is a case that is run on purpose.",
    cases=[
        C(
            "Restore the factory default and list sc_nonvol",
            doc=[
                "Step 1. Run sc_cli factory_default",
                "Step 2. List /mnt/sc_nonvol",
                "Step 3. Only s2p_files and s2pm5d may be left",
                "Step 4. The reboot that follows is a step of the bench procedure",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_factory_default.log",
            body=[
                "${default}=    IT COMMON - Run Dut Command And Return    sc_cli factory_default    timeout=120",
                "Log    ${default}",
                "${out}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol",
                "Log    ${out}",
                "Should Contain    ${out}    s2p_files",
                "Should Contain    ${out}    s2pm5d",
                "Should Not Contain    ${out}    ampapp_data.json",
                "Should Not Contain    ${out}    rfboard_data.json",
            ],
        ),
    ],
)

S(
    "CF-006",
    bench=True,
    sheet="CUST_FACING",
    area=BASIC,
    comment="Check that the syslog backup appears after the boot",
    doc="Three minutes after the boot the syslog_backup.tar.1.gz has to appear "
        "in sc_nonvol (User Guide 10.4). The reboot is a step of the bench "
        "procedure.",
    cases=[
        C(
            "Check that the syslog backup is there",
            doc=[
                "Step 1. Three minutes after the reboot the backup has to be there",
            ],
            tags=["FILE"],
            log="1_syslog_backup.log",
            body=[
                "${size}=    IT COMMON - Wait For File On Dut    /mnt/sc_nonvol/syslog_backup.tar.1.gz    timeout=300    interval=15",
                "Should Not Be Equal    ${size}    0",
            ],
        ),
    ],
)

S(
    "CF-007",
    sheet="CUST_FACING",
    area=BASIC,
    comment="Check the factory files, the non-volatile files and the EC PNM statistics",
    doc="Verify that the mandatory factory and non-volatile files exist and "
        "that the Broadcom EC PNM statistics can be collected (User Guide 2.1, "
        "2.2, 10.1).",
    cases=[
        C(
            "Check the mandatory factory files",
            doc=[
                "Step 1. Check the factory files of the 1.2G band",
                "Step 2. Check the factory files of the 1.8G band, they are optional",
            ],
            tags=["FILE"],
            log="1_factory_files.log",
            body=[
                "${mandatory}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_factory/MainBID.json /mnt/sc_factory/AmpMFGID.json /mnt/sc_factory/SP_DTS_OUT_1p2G_Mode.DAT /mnt/sc_factory/SF_WBFFT_ADC_DP0_Factory_1p2G_Mode.txt /mnt/sc_factory/SF_WBFFT_ADC_DP0_Factory_1p2G_Mode_Temp.txt",
                "Log    ${mandatory}",
                "Should Not Contain    ${mandatory}    No such file",
                "${optional}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_factory/SP_DTS_OUT_1p8G_Mode.DAT /mnt/sc_factory/SF_WBFFT_ADC_DP0_Factory_1p8G_Mode.txt /mnt/sc_factory/SF_WBFFT_ADC_DP0_Factory_1p8G_Mode_Temp.txt",
                "Log    ${optional}",
            ],
        ),
        C(
            "Check the non-volatile files",
            doc=[
                "Step 1. Check the non-volatile files of the DUT",
            ],
            tags=["FILE"],
            log="2_nonvol_files.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    ls -l /mnt/sc_nonvol/ampapp_data.json /mnt/sc_nonvol/rfboard_data.json /mnt/sc_nonvol/rfboard_data.json.default /mnt/sc_nonvol/sc_amp_cfg.json /mnt/sc_nonvol/s2p_files",
                "Log    ${out}",
                "Should Not Contain    ${out}    No such file",
            ],
        ),
        C(
            "Collect the EC PNM statistics",
            doc=[
                "Step 1. Run the EC PNM statistics command through the Broadcom CLI wrapper",
                "Step 2. The command has to complete",
            ],
            tags=["CLI"],
            log="3_ec_pnm.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    cliwrapper_client -c '/ec_pnm_stats 6 0' -s /tmp/brcmhal.sock -t 2000    timeout=60",
                "Log    ${out}",
            ],
        ),
    ],
)

S(
    "CF-008",
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Show the version of the device and of every AMP module",
    doc="Display the device information and the version of every AMP module "
        "(User Guide 3.1).",
    cases=[
        C(
            "Show the version of the device",
            doc=[
                "Step 1. Run show version",
                "Step 2. Check the six fields of the answer",
            ],
            tags=["CLI"],
            log="1_version.log",
            body=[
                "${out}=    IT COMMON - Run Fdx Command And Return    show version",
                "Log    ${out}",
                "Should Contain    ${out}    Device Type",
                "Should Contain    ${out}    Hardware Version",
                "Should Contain    ${out}    Part Number / Revision",
                "Should Contain    ${out}    Software Version",
                "Should Contain    ${out}    Number Of Components",
                "Should Contain    ${out}    System Uptime",
            ],
        ),
        C(
            "Show the version of every AMP module",
            doc=[
                "Step 1. Run show version details",
                "Step 2. The answer has to hold the details of the modules",
            ],
            tags=["CLI"],
            log="2_version_details.log",
            body=[
                "${out}=    IT COMMON - Run Fdx Command And Return    show version details",
                "Log    ${out}",
                "Should Not Be Equal    ${out}    ${EMPTY}",
            ],
        ),
    ],
)


def _ds_profile_clish_case(item_id, port, title, log):
    """Configure the ds-profile of one port through the clish view."""
    view = "ds-profile-%s" % port
    return C(
        title,
        doc=[
            "Step 1. Enter the ds-profile view of the %s port" % port,
            "Step 2. Set the name, the frequency and the power range",
            "Step 3. Set the step-down entry and commit",
            "Step 4. Show the configuration",
            "Step 5. Check the configuration in ampapp_data.json",
            "Step 6. Leave the view",
        ],
        tags=["CLI", "FILE", "WRITE"],
        log=log,
        body=[
            "${enter}=    IT COMMON - Fdx Enter View    configure ds-profile %s    %s" % (port, view),
            "${before}=    IT COMMON - Run Fdx View Command And Return    %s    show configuration" % view,
            "${name}=    IT COMMON - Run Fdx View Command And Return    %s    name profile-%stest" % (view, port),
            "${start_freq}=    IT COMMON - Run Fdx View Command And Return    %s    start-freq 109000001" % view,
            "${end_freq}=    IT COMMON - Run Fdx View Command And Return    %s    end-freq 1217000001" % view,
            "${start_power}=    IT COMMON - Run Fdx View Command And Return    %s    start-power 33.1" % view,
            "${end_power}=    IT COMMON - Run Fdx View Command And Return    %s    end-power 50.1" % view,
            "${step_freq}=    IT COMMON - Run Fdx View Command And Return    %s    step-down 0 start-freq 1001000001" % view,
            "${step_size}=    IT COMMON - Run Fdx View Command And Return    %s    step-down 0 size-db 3.0" % view,
            "${commit}=    IT COMMON - Run Fdx View Command And Return    %s    commit" % view,
            "${after}=    IT COMMON - Run Fdx View Command And Return    %s    show configuration" % view,
            "Log    ${after}",
            "Should Contain    ${after}    profile-%stest" % port,
            "Should Contain    ${after}    109000001",
            "Should Contain    ${after}    1217000001",
            "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json",
            "Should Contain    ${json}    %s_port_configuration" % port,
            "${exit}=    IT COMMON - Fdx Exit View    %s" % view,
        ],
    )


def _us_profile_clish_case(item_id, port, rlsp, title, log):
    """Configure the us-profile of one port through the clish view."""
    view = "us-profile-%s" % port
    return C(
        title,
        doc=[
            "Step 1. Enter the us-profile view of the %s port" % port,
            "Step 2. Set the rlsp and commit",
            "Step 3. Show the configuration",
            "Step 4. Check the configuration in ampapp_data.json",
            "Step 5. Leave the view",
        ],
        tags=["CLI", "FILE", "WRITE"],
        log=log,
        body=[
            "${enter}=    IT COMMON - Fdx Enter View    configure us-profile %s    %s" % (port, view),
            "${before}=    IT COMMON - Run Fdx View Command And Return    %s    show configuration" % view,
            "${rlsp_set}=    IT COMMON - Run Fdx View Command And Return    %s    rlsp %s" % (view, rlsp),
            "${commit}=    IT COMMON - Run Fdx View Command And Return    %s    commit" % view,
            "${after}=    IT COMMON - Run Fdx View Command And Return    %s    show configuration" % view,
            "Log    ${after}",
            "Should Contain    ${after}    %s" % rlsp,
            "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json",
            "Should Contain    ${json}    %s_port_configuration" % port,
            "${exit}=    IT COMMON - Fdx Exit View    %s" % view,
        ],
    )


S(
    "CF-009",
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Configure the ds-profile of the north port",
    doc="Configure the north port ds-profile (name, start and end frequency "
        "and power, step-down, OOB) and commit it (User Guide 3.2).",
    cases=[
        _ds_profile_clish_case("CF-009", "north", "Configure the ds-profile of the north port", "1_ds_profile.log"),
    ],
)

S(
    "CF-010",
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Configure the ds-profile of the south port",
    doc="Configure the south port ds-profile (name, start and end frequency "
        "and power, step-down, OOB) and commit it (User Guide 3.2).",
    cases=[
        _ds_profile_clish_case("CF-010", "south", "Configure the ds-profile of the south port", "1_ds_profile.log"),
    ],
)

S(
    "CF-011",
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Configure the us-profile of the north port",
    doc="Configure the north port us-profile (rlsp) and commit it "
        "(User Guide 3.3).",
    cases=[
        _us_profile_clish_case("CF-011", "north", "8.10", "Configure the us-profile of the north port", "1_us_profile.log"),
    ],
)

S(
    "CF-012",
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Configure the us-profile of the south port",
    doc="Configure the south port us-profile (rlsp) and commit it "
        "(User Guide 3.3).",
    cases=[
        _us_profile_clish_case("CF-012", "south", "8.20", "Configure the us-profile of the south port", "1_us_profile.log"),
    ],
)

S(
    "CF-013",
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Configure the spectrum allocation",
    doc="Configure the spectrum allocation (the downstream, the legacy "
        "upstream and the extended upstream frequency range, the subband "
        "modes) and commit it (User Guide 3.4).",
    cases=[
        C(
            "Configure the spectrum allocation and commit it",
            doc=[
                "Step 1. Enter the spectrum view",
                "Step 2. Set the frequency ranges",
                "Step 3. Set the three subbands and add a fourth one",
                "Step 4. Commit and show the configuration",
                "Step 5. Check the allocation in ampapp_data.json",
                "Step 6. Leave the view",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_spectrum.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum",
                "${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
                "${ds_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-start-freq 108000000",
                "${ds_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    ds-end-freq 1218000000",
                "${us_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-start-freq 5000000",
                "${us_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-legacy-end-freq 85000000",
                "${ext_start}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-start-freq 108000000",
                "${ext_end}=    IT COMMON - Run Fdx View Command And Return    spectrum    us-extended-end-freq 396000000",
                "${sub0}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 0 ds",
                "${sub1}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 1 ds",
                "${sub2}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband 2 ds",
                "${add}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband add bidi",
                "${remove}=    IT COMMON - Run Fdx View Command And Return    spectrum    subband remove 3",
                "${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit",
                "${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
                "Log    ${after}",
                "Should Contain    ${after}    108000000",
                "Should Contain    ${after}    1218000000",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_cli get_spectrum_allocation",
                "Log    ${cli}",
                "Should Contain    ${cli}    dsBeginHz: 108000000",
                "Should Contain    ${cli}    dsEndHz: 1218000000",
                "${exit}=    IT COMMON - Fdx Exit View    spectrum",
            ],
        ),
    ],
)

S(
    "CF-014",
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Add and remove a frequency exclusion",
    doc="Add and remove a frequency exclusion and commit it (User Guide 3.4).",
    cases=[
        C(
            "Add a frequency exclusion and commit it",
            doc=[
                "Step 1. Enter the spectrum view",
                "Step 2. Add the frequency exclusion and commit it",
                "Step 3. Check the exclusion in sc_cli get_spectrum_allocation",
                "Step 4. Leave the view",
            ],
            tags=["CLI", "WRITE"],
            log="1_add.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum",
                "${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
                "${add}=    IT COMMON - Run Fdx View Command And Return    spectrum    add freq-exclusion 150000000 200000000 PASS_OTHER INTERFERENCE",
                "${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit",
                "${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
                "Log    ${after}",
                "Should Contain    ${after}    150000000",
                "Should Contain    ${after}    200000000",
                "${exit}=    IT COMMON - Fdx Exit View    spectrum",
            ],
        ),
        C(
            "Remove the frequency exclusion and commit it",
            doc=[
                "Step 1. Enter the spectrum view",
                "Step 2. Remove the frequency exclusion and commit it",
                "Step 3. Check the exclusion in sc_cli get_spectrum_allocation",
                "Step 4. Leave the view",
            ],
            tags=["CLI", "WRITE"],
            log="2_remove.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    configure spectrum    spectrum",
                "${before}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
                "${remove}=    IT COMMON - Run Fdx View Command And Return    spectrum    remove freq-exclusion 0",
                "${commit}=    IT COMMON - Run Fdx View Command And Return    spectrum    commit",
                "${after}=    IT COMMON - Run Fdx View Command And Return    spectrum    show configuration",
                "Log    ${after}",
                "${exit}=    IT COMMON - Fdx Exit View    spectrum",
            ],
        ),
    ],
)

S(
    "CF-015",
    bench=True,
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Check that the configuration survives a reboot",
    doc="After a reboot every configuration has to stay the same. The reboot "
        "is a step of the bench procedure, so the case compares the "
        "configuration with the one that was read before the reboot.",
    cases=[
        C(
            "Read the configuration before and after the reboot",
            doc=[
                "Step 1. Read the configuration of the AMP application",
                "Step 2. The DUT has been rebooted in the meantime",
                "Step 3. Read the configuration again and compare the two",
            ],
            tags=["FILE"],
            log="1_reboot.log",
            body=[
                "${before_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json",
                "${before_version}=    Evaluate    $before_json.get('version')    modules=builtins",
                "${after_json}=    IT COMMON - Wait For Dut Json File    /mnt/sc_nonvol/ampapp_data.json",
                "${after_version}=    Evaluate    $after_json.get('version')    modules=builtins",
                "Should Be Equal    ${after_version}    ${before_version}",
            ],
        ),
    ],
)

S(
    "CF-016",
    sheet="CUST_FACING",
    area=COMCAST_CLI,
    comment="Show and set the rf-components through the clish",
    doc="Show all the rf-components through the clish and set the ones that "
        "the clish supports (User Guide 3.6). The template notes that the "
        "clish rf-component is not fully supported yet.",
    cases=[
        C(
            "Show the rf-components",
            doc=[
                "Step 1. Enter the rf-components view",
                "Step 2. Show the rf-components",
                "Step 3. Leave the view",
            ],
            tags=["CLI"],
            log="1_show.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    rf-components    rf-components",
                "${show}=    IT COMMON - Run Fdx View Command And Return    rf-components    show rf-components",
                "Log    ${show}",
                "Should Not Be Equal    ${show}    ${EMPTY}",
                "${exit}=    IT COMMON - Fdx Exit View    rf-components",
            ],
        ),
        C(
            "Check the rf-components with the Sercomm CLI",
            doc=[
                "Step 1. Read the PA current, the attenuation and the tilt of the RF board",
            ],
            tags=["CLI"],
            log="2_sc_rfboard.log",
            body=[
                "${pa}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_pa_current 0",
                "${atten}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "${tilt}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0",
                "Log    ${pa}",
                "Should Contain    ${pa}    DS_HYBRID_PA_BIAS",
                "Should Contain    ${atten}    NP_DS_ATT_BEFORE_LNA",
                "Should Contain    ${tilt}    SP_DS_1.2G_VEQ",
            ],
        ),
        C(
            "Check the rf-components in rfboard_data.json",
            doc=[
                "Step 1. Read rfboard_data.json",
                "Step 2. The file has to hold the attenuation, the tilt and the bias values",
            ],
            tags=["FILE"],
            log="3_rfboard_data.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json",
                "Log    ${out}",
                "Should Contain    ${out}    atten",
                "Should Contain    ${out}    tilt",
                "Should Contain    ${out}    bias",
            ],
        ),
    ],
)

S(
    "CF-017",
    sheet="CUST_FACING",
    area=SERCOMM_CLI,
    comment="The mandatory set and get commands of the Sercomm RF board CLI",
    doc="Verify the mandatory set and get commands of sc_rfboard_cli "
        "(User Guide 3.6). Every set is validated with its get command.",
    cases=[
        C(
            "Set and read the attenuation",
            doc=[
                "Step 1. Read the attenuation of the first entry",
                "Step 2. Set it and read it back",
            ],
            tags=["CLI", "WRITE"],
            log="1_attenuation.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_attenuation 2 8.0",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "Log    ${after}",
                "Should Contain    ${after}    SP_DS_ATT",
            ],
        ),
        C(
            "Set and read the variable tilt",
            doc=[
                "Step 1. Read the tilt of the second entry",
                "Step 2. Set it and read it back",
            ],
            tags=["CLI", "WRITE"],
            log="2_tilt.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_var_tilt 2 11.7",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 0",
                "Log    ${after}",
                "Should Contain    ${after}    SP_DS_1.2G_VEQ",
            ],
        ),
        C(
            "Set and read the PA current",
            doc=[
                "Step 1. Read the PA current",
                "Step 2. Set it and read it back",
            ],
            tags=["CLI", "WRITE"],
            log="3_pa_current.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_pa_current 0",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_pa_current 1 498.5",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_pa_current 0",
                "Log    ${after}",
                "Should Contain    ${after}    DS_HYBRID_PA_BIAS",
                "Should Contain    ${after}    US_FINAL_PA_BIAS",
            ],
        ),
        C(
            "Read the JXP tilt and the two calibration flags",
            doc=[
                "Step 1. Read the JXP tilt of the RF board",
                "Step 2. Read the two calibration flags",
                "Step 3. Set the NP monitor input and read it back",
            ],
            tags=["CLI", "WRITE"],
            log="4_flags.log",
            body=[
                "${jxp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_legacy_up_jxp_tilt",
                "Log    ${jxp}",
                "Should Contain    ${jxp}    get_legacy_up_jxp_tilt =",
                "${ignore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_np_ds_calib_adj",
                "Log    ${ignore}",
                "Should Contain    ${ignore}    get_ignore_np_ds_calib_adj =",
                "${auto}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_auto_adj_legacy_vatt",
                "Log    ${auto}",
                "Should Contain    ${auto}    get_auto_adj_legacy_vatt =",
                "${monitor}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_np_monitor_input us",
                "${input}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_np_monitor_input",
                "Log    ${input}",
                "${back}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_np_monitor_input ds",
                "${restored}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_np_monitor_input",
                "Log    ${restored}",
                "Should Contain    ${restored}    downstream",
            ],
        ),
    ],
)

S(
    "CF-018",
    sheet="CUST_FACING",
    area=SERCOMM_CLI,
    comment="The secondary commands of the Sercomm RF board CLI",
    doc="Exercise the secondary sc_rfboard_cli commands (the board control, "
        "the RF frequency, the raw PA current / attenuation / tilt, the NP DS "
        "adjustment, the EEPROM read, the RF board temperature, the AGC and "
        "FDX US ignore flags and the calibration reset) (User Guide 3.6, 10.8).",
    cases=[
        C(
            "Read the state of the RF board and its frequency",
            doc=[
                "Step 1. Read the state of the RF board",
                "Step 2. Read the RF frequency",
            ],
            tags=["CLI"],
            log="1_board.log",
            body=[
                "${state}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli board_state",
                "${freq}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_rf_frequency",
                "Log    ${state}",
                "Log    ${freq}",
                "Should Contain    ${state}    RF board state: ACTIVE",
                "Should Contain    ${freq}    RF frequency mode is set to",
            ],
        ),
        C(
            "Read the temperature of the RF board",
            doc=[
                "Step 1. Read the temperature of the local sensor and of the three channels",
            ],
            tags=["CLI"],
            log="2_temperature.log",
            body=[
                "${temp}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_rfboard_temperature all",
                "Log    ${temp}",
                "Should Contain    ${temp}    CHANNEL LOCAL",
                "Should Contain    ${temp}    CHANNEL 1",
                "Should Contain    ${temp}    CHANNEL 2",
                "Should Contain    ${temp}    CHANNEL 3",
            ],
        ),
        C(
            "Read the EEPROM partition table and dump a partition",
            doc=[
                "Step 1. Read the partition table",
                "Step 2. Read the first partition into a file",
                "Step 3. Check that the file is there",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="3_eeprom.log",
            body=[
                "${table}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli eeprom_get_partition_tale",
                "Log    ${table}",
                "Should Contain    ${table}    RFB_DATA",
                "${read}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli eeprom_partition_read 1 /tmp/eeprom_p1.bin    timeout=60",
                "Log    ${read}",
                "${size}=    IT COMMON - Wait For File On Dut    /tmp/eeprom_p1.bin    timeout=60",
                "Should Not Be Equal    ${size}    0",
            ],
        ),
        C(
            "Set and read the AGC and the FDX US ignore flags",
            doc=[
                "Step 1. Set the two flags and read them back",
                "Step 2. Put them back",
            ],
            tags=["CLI", "WRITE"],
            log="4_flags.log",
            body=[
                "${restore_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_restore_agc_adj 1",
                "${restore}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_restore_agc_adj",
                "Should Contain    ${restore}    get_ignore_restore_agc_adj = 1",
                "${reset_set}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_reset_fdx_us 1",
                "${reset}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_ignore_reset_fdx_us",
                "Should Contain    ${reset}    get_ignore_reset_fdx_us = 1",
                "${restore_back}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_restore_agc_adj 0",
                "${reset_back}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli set_ignore_reset_fdx_us 0",
            ],
        ),
        C(
            "Run the NP DS attenuation adjustment",
            doc=[
                "Step 1. Run the adjustment",
                "Step 2. Read the result of the adjustment",
            ],
            tags=["CLI", "WRITE"],
            log="5_adjust.log",
            body=[
                "${adjust}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli adjust_np_ds_atts 1.5 35 0    timeout=60",
                "Log    ${adjust}",
                "${result}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli adjust_np_ds_atts_result",
                "Log    ${result}",
                "Should Contain    ${result}    NP_DS_ATT_BEFORE_LNA",
                "Should Contain    ${result}    NP_DS_ATT_AFTER_LNA",
            ],
        ),
    ],
)

S(
    "CF-019",
    sheet="CUST_FACING",
    area=SERCOMM_CLI,
    comment="The north AFE target TCP",
    doc="Verify the north AFE target TCP configuration through sc_cli "
        "get and set_np_soc_target_tcp (User Guide 7.2.2).",
    cases=[
        C(
            "Read and set the north AFE target TCP",
            doc=[
                "Step 1. Read the current target TCP",
                "Step 2. Set it to 36 dBmV",
                "Step 3. Read it back",
                "Step 4. Put the original value back",
            ],
            tags=["CLI", "WRITE"],
            log="1_target_tcp.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp",
                "${old}=    IT COMMON - Get Inline Field    ${before}    value",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp 36",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp",
                "Log    ${after}",
                "IT COMMON - Cli Inline Number Should Equal    ${after}    value    36",
                "${back}=    IT COMMON - Run Dut Command And Return    sc_cli set_np_soc_target_tcp ${old}",
                "${restored}=    IT COMMON - Run Dut Command And Return    sc_cli get_np_soc_target_tcp",
                "IT COMMON - Cli Inline Number Should Equal    ${restored}    value    ${old}",
            ],
        ),
    ],
)

S(
    "CF-020",
    sheet="CUST_FACING",
    area=SERCOMM_CLI,
    comment="The north AFE backoff",
    doc="Verify the north AFE backoff configuration through sc_cli get and "
        "set_north_afe_back_off (User Guide 10.2).",
    cases=[
        C(
            "Read and set the north AFE backoff",
            doc=[
                "Step 1. Read the current backoff",
                "Step 2. Set it to 16.5 dB",
                "Step 3. Read it back",
                "Step 4. Put the original value back",
            ],
            tags=["CLI", "WRITE"],
            log="1_backoff.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_afe_back_off",
                "${old}=    IT COMMON - Get Cli Field    ${before}    afe",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_north_afe_back_off 16.5",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_afe_back_off",
                "Log    ${after}",
                "IT COMMON - Cli Number Should Equal    ${after}    afe    16.5",
                "${back}=    IT COMMON - Run Dut Command And Return    sc_cli set_north_afe_back_off ${old}",
                "${restored}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_afe_back_off",
                "IT COMMON - Cli Number Should Equal    ${restored}    afe    ${old}",
            ],
        ),
    ],
)

S(
    "CF-021",
    bench=True,
    sheet="CUST_FACING",
    area=SERCOMM_CLI,
    comment="The management IP mode",
    doc="Show the management port IP configuration (User Guide 10.6). The "
        "switch between DHCP and a static address drops the management "
        "connection, so it is a step of the bench procedure and is not done by "
        "the suite.",
    cases=[
        C(
            "Show the management IP configuration",
            doc=[
                "Step 1. Run mgmtip show",
                "Step 2. The answer has to hold the IP mode and the address",
            ],
            tags=["CLI"],
            log="1_mgmtip.log",
            body=[
                "${out}=    IT COMMON - Run Fdx Command And Return    mgmtip show",
                "Log    ${out}",
                "Should Not Be Equal    ${out}    ${EMPTY}",
            ],
        ),
    ],
)

S(
    "CF-022",
    sheet="CUST_FACING",
    area=SERCOMM_CLI,
    comment="Enable and disable the AGC",
    doc="Verify the AGC enable and disable through set_asc_config "
        "operationMode and the AGC log output (User Guide 8.4).",
    cases=[
        C(
            "Enable the AGC and check that it runs",
            doc=[
                "Step 1. Set the log level of the AGC to debug",
                "Step 2. Read the AGC and the ASC configuration",
                "Step 3. Set the operation mode to FreeRun",
                "Step 4. Read the ASC configuration back",
                "Step 5. Clear the calibration required flag so that the AGC runs",
                "Step 6. Read the state of the four state machines",
            ],
            tags=["CLI", "WRITE"],
            log="1_enable.log",
            body=[
                "${log}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 7",
                "Log    ${log}",
                "${agc}=    IT COMMON - Run Dut Command And Return    sc_cli get_agc_config",
                "${asc_before}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 1",
                "${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Should Contain    ${asc}    operationMode = FreeRun",
                "${flag}=    IT COMMON - Run Dut Command And Return    sc_cli get_calib_req_config_flag",
                "Log    ${flag}",
                "${clear}=    IT COMMON - Run Dut Command And Return    sc_cli set_calib_req_config_flag false",
            ] + [
                "${%s}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_fsm_status %s" % (fsm, fsm)
                for fsm in ["sp_ds", "np_ds", "clipping", "np_us"]
            ] + [
                "FOR    ${fsm}    IN    @{fsms}",
                "    ${state}=    IT COMMON - Get Cli Field    ${${fsm}}    enabled",
                "    Log    ${state}",
                "END",
            ],
            vars=[("fsms", ["sp_ds", "np_ds", "clipping", "np_us"])],
        ),
        C(
            "Disable the AGC and check that it is refused to start",
            doc=[
                "Step 1. Set the operation mode to Disable",
                "Step 2. Try to start the AGC control, it has to be refused",
                "Step 3. Set the log level of the AGC back to info",
            ],
            tags=["CLI", "WRITE"],
            log="2_disable.log",
            body=[
                "${set}=    IT COMMON - Run Dut Command And Return    sc_cli set_asc_config operationMode 0",
                "${asc}=    IT COMMON - Run Dut Command And Return    sc_cli get_asc_config",
                "Should Contain    ${asc}    operationMode = Disable",
                "${start}=    IT COMMON - Run Dut Command And Return    sc_cli set_agc_control start",
                "Log    ${start}",
                "Should Not Contain    ${start}    Success",
                "${log}=    IT COMMON - Run Dut Command And Return    sc_log_cli -z 20 -l 6",
            ],
        ),
    ],
)

S(
    "CF-023",
    bench=True,
    sheet="CUST_FACING",
    area=SERCOMM_CLI,
    comment="The firmware upgrade",
    doc="Upgrade the firmware through the Comcast CLI over HTTP or through the "
        "Broadcom brcmupgrade CLI (User Guide 11.1, 11.2). The upgrade itself "
        "is a step of the bench procedure, so the suite reads the version that "
        "is in place.",
    cases=[
        C(
            "Read the firmware version of the DUT",
            doc=[
                "Step 1. Read the version file of the DUT",
                "Step 2. Read the version through the clish",
                "Step 3. Both have to carry the same software version",
            ],
            tags=["CLI", "FILE"],
            log="1_version.log",
            body=[
                "${file}=    IT COMMON - Run Dut Command And Return    cat /sc_versions.txt",
                "Log    ${file}",
                "${clish}=    IT COMMON - Run Fdx Command And Return    show version",
                "Log    ${clish}",
                "Should Contain    ${clish}    Software Version",
            ],
        ),
    ],
)

S(
    "CF-024",
    bench=True,
    sheet="CUST_FACING",
    area=FW_SPECTRUM,
    comment="The downstream spectrum capture before a firmware upgrade",
    doc="Capture the downstream spectrum with the WBFFT capture of the "
        "firmware that is in place (User Guide 13). The firmware upgrade that "
        "the template asks for is a step of the bench procedure, so the suite "
        "runs the capture and the comparison of the two captures it finds.",
    vars=[("capture_file", "/mnt/nonvol_active/wbfft_capture_before_fw_upgrade.txt")],
    cases=[
        C(
            "Run the WBFFT capture of the current firmware",
            doc=[
                "Step 1. Run the WBFFT capture and write it to a file",
                "Step 2. Check that the file holds the capture",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_capture.log",
            body=[
                "${capture}=    IT COMMON - Run Dut Command And Return    sc_cli wbfft_capture 0 1218000000 32768 1647000000 FreqDomainPower None Time 6 200 Dp0 false 0 1 1000 > ${capture_file}    timeout=300",
                "Log    ${capture}",
                "${size}=    IT COMMON - Wait For File On Dut    ${capture_file}    timeout=120",
                "Should Not Be Equal    ${size}    0",
            ],
        ),
    ],
)

S(
    "CF-025",
    bench=True,
    sheet="CUST_FACING",
    area=FW_SPECTRUM,
    comment="The downstream spectrum capture after a firmware downgrade",
    doc="Capture the downstream spectrum with the WBFFT capture of the "
        "firmware that is in place and compare it with the capture of the "
        "reference firmware (User Guide 13). The downgrade itself is a step of "
        "the bench procedure.",
    vars=[
        ("capture_file", "/mnt/nonvol_active/wbfft_capture_after_fw_downgrade.txt"),
        ("reference_file", "/mnt/nonvol_active/wbfft_capture_before_fw_upgrade.txt"),
    ],
    cases=[
        C(
            "Run the WBFFT capture of the firmware in place",
            doc=[
                "Step 1. Run the WBFFT capture and write it to a file",
                "Step 2. Check that the file holds the capture",
            ],
            tags=["CLI", "FILE", "WRITE"],
            log="1_capture.log",
            body=[
                "${capture}=    IT COMMON - Run Dut Command And Return    sc_cli wbfft_capture 0 1218000000 32768 1647000000 FreqDomainPower None Time 6 200 Dp0 false 0 1 1000 > ${capture_file}    timeout=300",
                "Log    ${capture}",
                "${size}=    IT COMMON - Wait For File On Dut    ${capture_file}    timeout=120",
                "Should Not Be Equal    ${size}    0",
            ],
        ),
        C(
            "Compare the two captures",
            doc=[
                "Step 1. Read the capture of the reference firmware",
                "Step 2. Read the capture of the firmware in place",
                "Step 3. Both have to hold the same number of bins",
            ],
            tags=["FILE"],
            log="2_compare.log",
            body=[
                "${reference}=    IT COMMON - Run Dut Command And Return    cat ${reference_file}",
                "${current}=    IT COMMON - Run Dut Command And Return    cat ${capture_file}",
                "Should Not Be Equal    ${reference}    ${EMPTY}",
                "Should Not Be Equal    ${current}    ${EMPTY}",
                "${reference_bins}=    Evaluate    len($reference.split())    modules=builtins",
                "${current_bins}=    Evaluate    len($current.split())    modules=builtins",
                "Should Be Equal    ${current_bins}    ${reference_bins}",
            ],
        ),
    ],
)

S(
    "CF-026",
    sheet="CUST_FACING",
    area=LEDS,
    comment="The ICS button, pressed once",
    doc="Press the ICS button once: 8 dB attenuation, the mode times out "
        "after 40 minutes and the top ICS LED turns on (User Guide 1.4). The "
        "button is a physical one, so the case reads the state of the LEDs "
        "after the button was pressed.",
    cases=[
        C(
            "Read the state of the LEDs after one press of the ICS button",
            doc=[
                "Step 1. The ICS button was pressed once",
                "Step 2. Read the attenuation of the RF board, it has to carry the 8 dB",
            ],
            tags=["CLI"],
            log="1_ics8.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "Log    ${out}",
                "Should Contain    ${out}    US_FDX_OUT_ATT",
            ],
        ),
    ],
)

S(
    "CF-027",
    sheet="CUST_FACING",
    area=LEDS,
    comment="The ICS button, pressed twice",
    doc="Press the ICS button twice: 16 dB attenuation, the mode times out "
        "after 20 minutes and the second ICS LED turns on (User Guide 1.4).",
    cases=[
        C(
            "Read the state of the LEDs after two presses of the ICS button",
            doc=[
                "Step 1. The ICS button was pressed twice",
                "Step 2. Read the attenuation of the RF board",
            ],
            tags=["CLI"],
            log="1_ics16.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "Log    ${out}",
                "Should Contain    ${out}    US_FDX_OUT_ATT",
            ],
        ),
    ],
)

S(
    "CF-028",
    sheet="CUST_FACING",
    area=LEDS,
    comment="The ICS button, pressed three times",
    doc="Press the ICS button three times: back to the default and no ICS LED "
        "turns on (User Guide 1.4).",
    cases=[
        C(
            "Read the state of the LEDs after three presses of the ICS button",
            doc=[
                "Step 1. The ICS button was pressed three times",
                "Step 2. Read the attenuation of the RF board",
            ],
            tags=["CLI"],
            log="1_ics_disable.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 0",
                "Log    ${out}",
                "Should Contain    ${out}    US_FDX_OUT_ATT",
            ],
        ),
    ],
)


def _sc_led_case(item_id, led, color, title, log):
    """Turn one LED on and off again with the sc_led CLI."""
    return C(
        title,
        doc=[
            "Step 1. Turn the %s LED on" % led,
            "Step 2. Turn the %s LED off again" % led,
        ],
        tags=["CLI", "WRITE"],
        log=log,
        body=[
            "${on}=    IT COMMON - Run Fdx Command And Return    sc_led -l %s -c %s -o on" % (led, color),
            "Log    ${on}",
            "${off}=    IT COMMON - Run Fdx Command And Return    sc_led -l %s -c %s -o off" % (led, color),
            "Log    ${off}",
        ],
    )


S(
    "CF-029",
    sheet="CUST_FACING",
    area=LEDS,
    comment="The SYS OK LED",
    doc="Using the sc_led CLI, verify the on and the off state of the SYS_OK "
        "LED (User Guide 1.3).",
    cases=[
        _sc_led_case("CF-029", "sys_ok", "green", "Turn the SYS OK LED on and off", "1_sys_ok.log"),
    ],
)

S(
    "CF-030",
    sheet="CUST_FACING",
    area=LEDS,
    comment="The CM LED",
    doc="Using the sc_led CLI, verify the on and the off state of the CM LED "
        "(User Guide 1.3).",
    cases=[
        _sc_led_case("CF-030", "cm", "green", "Turn the CM LED on and off", "1_cm.log"),
    ],
)

S(
    "CF-031",
    sheet="CUST_FACING",
    area=LEDS,
    comment="The ICS 8 dB LED",
    doc="Using the sc_led CLI, verify the on and the off state of the ICS_8 "
        "LED (User Guide 1.3).",
    cases=[
        _sc_led_case("CF-031", "ics_8", "orange", "Turn the ICS 8 dB LED on and off", "1_ics8.log"),
    ],
)

S(
    "CF-032",
    sheet="CUST_FACING",
    area=LEDS,
    comment="The ICS 16 dB LED",
    doc="Using the sc_led CLI, verify the on and the off state of the "
        "ICS_16 LED (User Guide 1.3).",
    cases=[
        _sc_led_case("CF-032", "ics_16", "orange", "Turn the ICS 16 dB LED on and off", "1_ics16.log"),
    ],
)

S(
    "CF-033",
    sheet="CUST_FACING",
    area=LEDS,
    comment="The functional LED state machine",
    doc="Verify the functional LED state machine (the power, the boot and the "
        "CM operational states) as opposed to the sc_led manual override of "
        "CF-029 to CF-032 (User Guide 1.3). The states are read over gNMI.",
    cases=[
        C(
            "Read the system status over gNMI",
            doc=[
                "Step 1. GET system-status",
                "Step 2. Check that it holds the crash status and the reboot info",
            ],
            tags=["GNMI"],
            log="1_system_status.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    system-status",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    system-status",
                "Log    ${value}",
                "Should Not Be Equal    ${value}    ${EMPTY}",
            ],
        ),
    ],
)
