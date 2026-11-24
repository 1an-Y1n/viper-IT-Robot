"""The CUST_FACING sheet of the LE IT test template: CF-034 to CF-061.

CF-054 appears twice in the template, with two different content blocks: the
WBFFT capture and the hardware installation. Both of them are two test cases
of one suite.
"""

from writer import C, S

GNMI_TESTS = "GNMI Tests"
GRPC_TESTS = "GRPC Tests"
DS_TRACKER = "DS Tracker (Ch13)"
SSH = "SSH (Ch14)"
MSC = "MSC (sc_msc_cli)"


def _gnmi_get_case(item_id, title, path, log, tags=None):
    """Read one gNMI path and check that the answer is there."""
    return C(
        title,
        doc=[
            "Step 1. GET %s" % path,
            "Step 2. The answer has to hold the value of the path",
        ],
        tags=tags or ["GNMI"],
        log=log,
        vars=[("path", path)],
        body=[
            "${response}=    IT COMMON - Gnmi Get And Return    ${path}",
            "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}",
            "Log    ${value}",
            "Should Not Be Equal    ${value}    ${EMPTY}",
        ],
    )


def _gnmi_set_case(item_id, title, path, updates, log, tags=None):
    """SET a gNMI path and read it back."""
    body = [
        "${before}=    IT COMMON - Gnmi Get And Return    ${path}",
        "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
        "Log    ${set}",
        "Should Contain    ${set}    UPDATE",
        "${after}=    IT COMMON - Gnmi Get And Return    ${path}",
        "${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    ${path}",
        "Log    ${value}",
    ]
    return C(
        title,
        doc=[
            "Step 1. GET %s, the value that is in place now" % path,
            "Step 2. SET the new value",
            "Step 3. GET it again and check that it took",
        ],
        tags=tags or ["GNMI", "WRITE"],
        log=log,
        vars=[("path", path), ("updates", updates)],
        body=body,
    )


S(
    "CF-034",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Read the capabilities of the gNMI server",
    doc="Basic sanity check that the gNMI is working (User Guide 9.1).",
    cases=[
        C(
            "Read the capabilities of the gNMI server",
            doc=[
                "Step 1. Run gnmic capabilities",
                "Step 2. The answer has to list the models of the server",
            ],
            tags=["GNMI"],
            log="1_capabilities.log",
            body=[
                "${raw}=    IT COMMON - Gnmi Capabilities And Return",
                "Log    ${raw}",
                "Should Contain    ${raw}    gNMI version",
                "Should Contain    ${raw}    supported models",
                "Should Contain    ${raw}    supported encodings",
            ],
        ),
    ],
)

S(
    "CF-035",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Walk the whole data tree",
    doc="Retrieve the entire data tree over gNMI (User Guide 9.1).",
    cases=[
        C(
            "Walk the whole data tree",
            doc=[
                "Step 1. GET the whole tree",
                "Step 2. The answer has to hold the top level containers",
            ],
            tags=["GNMI"],
            log="1_walk.log",
            body=[
                "${raw}=    IT COMMON - Gnmi Get Raw    ${EMPTY}    timeout=120",
                "Log    ${raw}",
                "Should Contain    ${raw}    amp-identification",
                "Should Contain    ${raw}    pab-result",
                "Should Contain    ${raw}    system-status",
            ],
        ),
    ],
)

S(
    "CF-036",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Read and set the amp-identification over gNMI",
    doc="Retrieve the amp-identification and set its nine fields over gNMI "
        "(User Guide 9.11).",
    vars=[("path", "amp-identification")],
    cases=[
        C(
            "GET the amp-identification",
            doc=[
                "Step 1. GET amp-identification",
                "Step 2. The answer has to hold the identity of the device",
            ],
            tags=["GNMI"],
            log="1_get.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    amp-identification",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    amp-identification",
                "Log    ${value}",
                "${serial}=    IT COMMON - Get Dict Field    ${value}    serial-number",
                "Should Be Equal    ${serial}    ${DUT_IT_SERIAL}",
                "${vendor}=    IT COMMON - Get Dict Field    ${value}    vendor-name",
                "Should Be Equal    ${vendor}    SERCOMM",
                "${mac}=    IT COMMON - Get Dict Field    ${value}    device-mac-address",
                "Log    ${mac}",
            ],
        ),
        C(
            "SET the nine fields of the amp-identification",
            doc=[
                "Step 1. SET the description and the geo position",
                "Step 2. GET the answer back and check the nine fields",
            ],
            tags=["GNMI", "WRITE"],
            log="2_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/amp-identification/device-location/description:::string:::Location",
                        "/amp-identification/device-location/geo/latitude/direction:::string:::NORTH",
                        "/amp-identification/device-location/geo/latitude/degrees:::uint:::37",
                        "/amp-identification/device-location/geo/latitude/minutes:::uint:::47",
                        "/amp-identification/device-location/geo/latitude/seconds:::uint:::30",
                        "/amp-identification/device-location/geo/longitude/direction:::string:::WEST",
                        "/amp-identification/device-location/geo/longitude/degrees:::uint:::122",
                        "/amp-identification/device-location/geo/longitude/minutes:::uint:::25",
                        "/amp-identification/device-location/geo/longitude/seconds:::uint:::10",
                    ],
                ),
            ],
            body=[
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "${response}=    IT COMMON - Gnmi Get And Return    amp-identification",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    amp-identification",
                "${location}=    IT COMMON - Get Dict Field    ${value}    device-location",
                "${description}=    IT COMMON - Get Dict Field    ${location}    description",
                "Should Be Equal    ${description}    Location",
                "${geo}=    IT COMMON - Get Dict Field    ${location}    geo",
                "${latitude}=    IT COMMON - Get Dict Field    ${geo}    latitude",
                "${degrees}=    IT COMMON - Get Dict Field    ${latitude}    degrees",
                "Should Be Equal As Integers    ${degrees}    37",
                "${longitude}=    IT COMMON - Get Dict Field    ${geo}    longitude",
                "${west}=    IT COMMON - Get Dict Field    ${longitude}    direction",
                "Should Be Equal    ${west}    WEST",
            ],
        ),
    ],
)

S(
    "CF-037",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set and read the ds-profile of both ports over gNMI",
    doc="Use a gNMI request to SET and GET the ds-profile of the "
        "north-port-configuration (User Guide 9.3). The two ports have to carry "
        "the same configuration.",
    cases=[
        C(
            "GET the ds-profile of both ports",
            doc=[
                "Step 1. GET the ds-profile of the two ports",
                "Step 2. Both answers have to hold a data-set-name",
            ],
            tags=["GNMI"],
            log="1_get.log",
            body=[
                "${north}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]",
                "${north_value}=    IT COMMON - Gnmi Get Leaf Value    ${north}    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]",
                "${south}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]",
                "${south_value}=    IT COMMON - Gnmi Get Leaf Value    ${south}    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]",
                "Log    ${north_value}",
                "Log    ${south_value}",
            ],
        ),
        C(
            "SET the ds-profile of both ports in one atomic request",
            doc=[
                "Step 1. SET the ds-profile of the north and of the south port",
                "Step 2. GET both ports again and compare the values",
            ],
            tags=["GNMI", "WRITE"],
            log="2_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/data-set-name:::string:::TEST_PROFILE",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/ds-power-min-freq-dbmv:::float:::26.00",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/ds-power-max-freq-dbmv:::float:::45.00",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/min-frequency-hertz:::uint:::108000000",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]/max-frequency-hertz:::uint:::1217000000",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/data-set-name:::string:::TEST_PROFILE",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/ds-power-min-freq-dbmv:::float:::26.00",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/ds-power-max-freq-dbmv:::float:::45.00",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/min-frequency-hertz:::uint:::108000000",
                        "/ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]/max-frequency-hertz:::uint:::1217000000",
                        "/ds-profile/step[step-index=0]/step-db:::float:::0",
                        "/ds-profile/step[step-index=0]/step-frequency-hz:::uint:::1002000000",
                    ],
                ),
            ],
            body=[
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "${north}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]",
                "${north_value}=    IT COMMON - Gnmi Get Leaf Value    ${north}    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]",
                "${south}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]",
                "${south_value}=    IT COMMON - Gnmi Get Leaf Value    ${south}    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]",
                "${north_name}=    IT COMMON - Get Dict Field    ${north_value}    data-set-name",
                "${south_name}=    IT COMMON - Get Dict Field    ${south_value}    data-set-name",
                "Should Be Equal    ${north_name}    TEST_PROFILE",
                "Should Be Equal    ${south_name}    TEST_PROFILE",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json",
                "Should Contain    ${json}    north_port_configuration",
                "Should Contain    ${json}    south_port_configuration",
            ],
        ),
    ],
)

S(
    "CF-038",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Read the ds-profile of the south port over gNMI",
    doc="Read the ds-profile of the south port over gNMI and compare it with "
        "the north port (User Guide 9.3).",
    cases=[
        C(
            "GET the ds-profile of the south port and compare it with the north port",
            doc=[
                "Step 1. GET the ds-profile of the south port",
                "Step 2. GET the ds-profile of the north port",
                "Step 3. The two have to carry the same values",
            ],
            tags=["GNMI"],
            log="1_get.log",
            body=[
                "${south}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]",
                "${south_value}=    IT COMMON - Gnmi Get Leaf Value    ${south}    /ds-profile/ds-port-configuration[port=AMP_PORT_SOUTH]",
                "${north}=    IT COMMON - Gnmi Get And Return    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]",
                "${north_value}=    IT COMMON - Gnmi Get Leaf Value    ${north}    /ds-profile/ds-port-configuration[port=AMP_PORT_NORTH]",
                "${south_name}=    IT COMMON - Get Dict Field    ${south_value}    data-set-name",
                "${north_name}=    IT COMMON - Get Dict Field    ${north_value}    data-set-name",
                "Should Be Equal    ${south_name}    ${north_name}",
                "${south_min}=    IT COMMON - Get Dict Field    ${south_value}    min-frequency-hertz",
                "${north_min}=    IT COMMON - Get Dict Field    ${north_value}    min-frequency-hertz",
                "Should Be Equal    ${south_min}    ${north_min}",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json",
                "Should Contain    ${json}    south_port_configuration",
            ],
        ),
    ],
)

S(
    "CF-039",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the rlsp of the north port over gNMI",
    doc="Read the us-profile of the north port and set its rlsp-dbmv over gNMI "
        "(User Guide 9.3.2).",
    cases=[
        C(
            "SET the rlsp of the north port",
            doc=[
                "Step 1. GET the us-profile of the north port",
                "Step 2. SET the rlsp-dbmv",
                "Step 3. GET it again and check that it took",
                "Step 4. Check the value in ampapp_data.json",
            ],
            tags=["GNMI", "FILE", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/us-profile/us-port-configuration[port=AMP_PORT_NORTH]/rlsp-dbmv:::float:::10",
                    ],
                ),
            ],
            body=[
                "${before}=    IT COMMON - Gnmi Get And Return    /us-profile/us-port-configuration[port=AMP_PORT_NORTH]",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "${after}=    IT COMMON - Gnmi Get And Return    /us-profile/us-port-configuration[port=AMP_PORT_NORTH]",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    /us-profile/us-port-configuration[port=AMP_PORT_NORTH]",
                "${rlsp}=    IT COMMON - Get Dict Field    ${value}    rlsp-dbmv",
                "Should Be Equal As Integers    ${rlsp}    10",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json",
                "Should Contain    ${json}    north_port_configuration",
            ],
        ),
    ],
)

S(
    "CF-040",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the rlsp of the south port over gNMI",
    doc="Read the us-profile of the south port and set its rlsp-dbmv over gNMI "
        "(User Guide 9.3.2).",
    cases=[
        C(
            "SET the rlsp of the south port",
            doc=[
                "Step 1. GET the us-profile of the south port",
                "Step 2. SET the rlsp-dbmv",
                "Step 3. GET it again and check that it took",
                "Step 4. Check the value in ampapp_data.json",
            ],
            tags=["GNMI", "FILE", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/us-profile/us-port-configuration[port=AMP_PORT_SOUTH]/rlsp-dbmv:::float:::10",
                    ],
                ),
            ],
            body=[
                "${before}=    IT COMMON - Gnmi Get And Return    /us-profile/us-port-configuration[port=AMP_PORT_SOUTH]",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "${after}=    IT COMMON - Gnmi Get And Return    /us-profile/us-port-configuration[port=AMP_PORT_SOUTH]",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    /us-profile/us-port-configuration[port=AMP_PORT_SOUTH]",
                "${rlsp}=    IT COMMON - Get Dict Field    ${value}    rlsp-dbmv",
                "Should Be Equal As Integers    ${rlsp}    10",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json",
                "Should Contain    ${json}    south_port_configuration",
            ],
        ),
    ],
)

S(
    "CF-041",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the spectrum allocation over gNMI",
    doc="Set the spectrum allocation to the Midsplit 1.2GHz with the frequency "
        "exclusions over gNMI (User Guide 9.4).",
    cases=[
        C(
            "GET and SET the spectrum allocation over gNMI",
            doc=[
                "Step 1. GET /spectrum-allocation",
                "Step 2. SET the allocation",
                "Step 3. GET it again and check the values",
                "Step 4. Check the values in ampapp_data.json",
            ],
            tags=["GNMI", "FILE", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/spectrum-allocation/ds-begin-hz:::uint:::108000000",
                        "/spectrum-allocation/ds-end-hz:::uint:::1218000000",
                        "/spectrum-allocation/us-legacy-begin-hz:::uint:::5000000",
                        "/spectrum-allocation/us-legacy-end-hz:::uint:::85000000",
                        "/spectrum-allocation/us-extended-begin-hz:::uint:::108000000",
                        "/spectrum-allocation/us-extended-end-hz:::uint:::684000000",
                        "/spectrum-allocation/subband-modes[subband-index=0]/subband-mode:::string:::SUBBAND_MODE_BIDIRECTIONAL",
                        "/spectrum-allocation/subband-modes[subband-index=1]/subband-mode:::string:::SUBBAND_MODE_BIDIRECTIONAL",
                        "/spectrum-allocation/subband-modes[subband-index=2]/subband-mode:::string:::SUBBAND_MODE_BIDIRECTIONAL",
                        "/spectrum-allocation/frequency-exclusions[index=0]/start-hz:::uint:::383000000",
                        "/spectrum-allocation/frequency-exclusions[index=0]/end-hz:::uint:::396000000",
                        "/spectrum-allocation/frequency-exclusions[index=0]/ds-fe-type:::string:::DS_FE_PASS_OTHER",
                        "/spectrum-allocation/frequency-exclusions[index=0]/us-fe-type:::string:::US_FE_EXCLUDED",
                    ],
                ),
            ],
            body=[
                "${before}=    IT COMMON - Gnmi Get And Return    /spectrum-allocation",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "${after}=    IT COMMON - Gnmi Get And Return    /spectrum-allocation",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    /spectrum-allocation",
                "${ds_begin}=    IT COMMON - Get Dict Field    ${value}    ds-begin-hz",
                "Should Be Equal As Integers    ${ds_begin}    108000000",
                "${ds_end}=    IT COMMON - Get Dict Field    ${value}    ds-end-hz",
                "Should Be Equal As Integers    ${ds_end}    1218000000",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/ampapp_data.json",
                "Should Contain    ${json}    spectrum",
            ],
        ),
    ],
)

S(
    "CF-042",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Show the rf-components over gNMI and over the clish",
    doc="Display all the available rf-components (User Guide 9.2).",
    cases=[
        C(
            "GET the rf-components over gNMI",
            doc=[
                "Step 1. GET /rf-components",
                "Step 2. The answer has to hold the components of the User Guide 9.2.1 table",
            ],
            tags=["GNMI"],
            log="1_get.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    /rf-components",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    /rf-components",
                "Log    ${value}",
                "IT COMMON - Gnmi Leaf Should Exist    ${value}    ds-output-port-atten",
                "IT COMMON - Gnmi Leaf Should Exist    ${value}    us-fdx-attenuation-db",
                "IT COMMON - Gnmi Leaf Should Exist    ${value}    north-port-switch-path",
            ],
        ),
        C(
            "GET the rf-components that have no table of their own",
            doc=[
                "Step 1. GET the five components of the User Guide 9.2.1 note",
            ],
            tags=["GNMI"],
            log="2_uncovered.log",
            vars=[
                (
                    "paths",
                    [
                        "/rf-components/north-afe-equalization-db[index=0]/equalization-db",
                        "/rf-components/north-afe-equalization-db[index=1]/equalization-db",
                        "/rf-components/us-fdx-input-attenuation-db[port=AMP_PORT_MAIN]/attenuation-db",
                        "/rf-components/north-us-pa-bias",
                        "/rf-components/south-ds-pa-bias",
                    ],
                ),
            ],
            body=[
                "FOR    ${path}    IN    @{paths}",
                "    ${response}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}",
                "    Log    ${value}",
                "END",
            ],
        ),
        C(
            "Show the rf-components through the clish",
            doc=[
                "Step 1. Enter the rf-components view",
                "Step 2. Show the rf-components",
                "Step 3. Leave the view",
            ],
            tags=["CLI"],
            log="3_clish.log",
            body=[
                "${enter}=    IT COMMON - Fdx Enter View    rf-components    rf-components",
                "${show}=    IT COMMON - Run Fdx View Command And Return    rf-components    show rf-components",
                "Log    ${show}",
                "Should Not Be Equal    ${show}    ${EMPTY}",
                "${exit}=    IT COMMON - Fdx Exit View    rf-components",
            ],
        ),
    ],
)

S(
    "CF-043",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the north AFE attenuation over gNMI",
    doc="Modify the north-afe-atten rf-components with gNMI and read the "
        "values back (User Guide 9.2.2).",
    cases=[
        C(
            "SET the three north AFE attenuations over gNMI",
            doc=[
                "Step 1. GET the three attenuations",
                "Step 2. SET the three attenuations",
                "Step 3. GET them again and check that they took",
            ],
            tags=["GNMI", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/rf-components/north-afe-attenuation-db[index=0]/attenuation-db:::float:::19.0",
                        "/rf-components/north-afe-attenuation-db[index=1]/attenuation-db:::float:::20.0",
                        "/rf-components/north-afe-attenuation-db[index=2]/attenuation-db:::float:::21.0",
                    ],
                ),
                (
                    "paths",
                    [
                        "/rf-components/north-afe-attenuation-db[index=0]",
                        "/rf-components/north-afe-attenuation-db[index=1]",
                        "/rf-components/north-afe-attenuation-db[index=2]",
                    ],
                ),
            ],
            body=[
                "FOR    ${path}    IN    @{paths}",
                "    ${before}=    IT COMMON - Gnmi Get And Return    ${path}",
                "END",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "FOR    ${path}    IN    @{paths}",
                "    ${after}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    ${path}",
                "    Log    ${value}",
                "END",
            ],
        ),
        C(
            "Check the attenuations in rfboard_data.json",
            doc=[
                "Step 1. Read rfboard_data.json",
                "Step 2. The file has to hold the attenuation values",
            ],
            tags=["FILE"],
            log="2_rfboard_data.log",
            body=[
                "${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json",
                "Log    ${out}",
                "Should Contain    ${out}    atten",
            ],
        ),
    ],
)

S(
    "CF-044",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Read the SP DS ATT over gNMI",
    doc="Read the SP_DS_ATT rf-component over the two downstream attenuation "
        "paths (User Guide 9.2.1).",
    cases=[
        C(
            "GET the SP DS attenuation over both paths",
            doc=[
                "Step 1. GET the non-volatile attenuation",
                "Step 2. GET the volatile attenuation",
                "Step 3. Compare both with sc_rfboard_cli",
            ],
            tags=["GNMI", "CLI"],
            log="1_get.log",
            vars=[
                (
                    "paths",
                    [
                        "/rf-components/ds-output-port-atten[port=AMP_PORT_MAIN]/attenuation-db",
                        "/rf-components/ds-output-port-atten-volatile[port=AMP_PORT_MAIN]/attenuation-db",
                    ],
                ),
            ],
            body=[
                "FOR    ${path}    IN    @{paths}",
                "    ${response}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}",
                "    Log    ${value}",
                "END",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 2",
                "Log    ${cli}",
                "Should Contain    ${cli}    SP_DS_ATT",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json",
                "Should Contain    ${json}    sp_ds_att_attenuation_db",
            ],
        ),
    ],
)

S(
    "CF-045",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the SP DS 1.2G VEQ over gNMI",
    doc="Modify the SP_DS_1.2G_VEQ rf-component with gNMI and read the value "
        "back (User Guide 9.2.2).",
    cases=[
        C(
            "SET the SP DS 1.2G VEQ over gNMI",
            doc=[
                "Step 1. GET the equalization of the downstream output",
                "Step 2. SET the non-volatile and the volatile value",
                "Step 3. GET them again and compare with sc_rfboard_cli",
            ],
            tags=["GNMI", "CLI", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/rf-components/ds-output-eq-db[index=0]/equalization-db:::float:::19.0",
                        "/rf-components/ds-output-eq-volatile-db[index=0]/equalization-db:::float:::11.0",
                    ],
                ),
                (
                    "paths",
                    [
                        "/rf-components/ds-output-eq-db[index=0]/equalization-db",
                        "/rf-components/ds-output-eq-volatile-db[index=0]/equalization-db",
                    ],
                ),
            ],
            body=[
                "FOR    ${path}    IN    @{paths}",
                "    ${before}=    IT COMMON - Gnmi Get And Return    ${path}",
                "END",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "FOR    ${path}    IN    @{paths}",
                "    ${after}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    ${path}",
                "    Log    ${value}",
                "END",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 2",
                "Log    ${cli}",
                "Should Contain    ${cli}    SP_DS_1.2G_VEQ",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json",
                "Should Contain    ${json}    sp_ds_1p2g_veq_tilt_db",
            ],
        ),
    ],
)

S(
    "CF-046",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the PA biases over gNMI",
    doc="Modify the PA bias rf-components (DS_HYBRID_PA_BIAS, "
        "US_FINAL_PA_BIAS, DS_DRIVER_BIAS) with gNMI and read the values back "
        "(User Guide 9.2.2).",
    cases=[
        C(
            "SET the three PA biases over gNMI",
            doc=[
                "Step 1. GET the PA bias of the main port",
                "Step 2. SET the three PA biases",
                "Step 3. GET them again and compare with sc_rfboard_cli",
            ],
            tags=["GNMI", "CLI", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/rf-components/pa-bias[port=AMP_PORT_MAIN]/current-ma:::float:::369",
                        "/rf-components/north-us-pa-bias:::float:::427.5",
                        "/rf-components/south-ds-pa-bias:::float:::334.5",
                    ],
                ),
                (
                    "paths",
                    [
                        "/rf-components/pa-bias[port=AMP_PORT_MAIN]/current-ma",
                        "/rf-components/north-us-pa-bias",
                        "/rf-components/south-ds-pa-bias",
                    ],
                ),
            ],
            body=[
                "FOR    ${path}    IN    @{paths}",
                "    ${before}=    IT COMMON - Gnmi Get And Return    ${path}",
                "END",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "FOR    ${path}    IN    @{paths}",
                "    ${after}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    ${path}",
                "    Log    ${value}",
                "END",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_pa_current 1",
                "Log    ${cli}",
                "Should Contain    ${cli}    PA_BIAS",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json",
                "Should Contain    ${json}    pa_bias",
            ],
        ),
    ],
)

S(
    "CF-047",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the US legacy attenuation before the LNA over gNMI",
    doc="Modify the US_LEGACY_ATT_BEFORE_LNA rf-component with gNMI and read "
        "the values back (User Guide 9.2.2).",
    cases=[
        C(
            "SET the US legacy attenuations over gNMI",
            doc=[
                "Step 1. GET the legacy upstream input attenuations",
                "Step 2. SET the two attenuations",
                "Step 3. GET them again and compare with sc_rfboard_cli",
            ],
            tags=["GNMI", "CLI", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/rf-components/legacy-us-input-atten[port=AMP_PORT_MAIN][index=0]/attenuation-db:::float:::17.5",
                        "/rf-components/legacy-us-input-atten[port=AMP_PORT_MAIN][index=1]/attenuation-db:::float:::19.5",
                    ],
                ),
                (
                    "paths",
                    [
                        "/rf-components/legacy-us-input-atten[port=AMP_PORT_MAIN][index=0]/attenuation-db",
                        "/rf-components/legacy-us-input-atten[port=AMP_PORT_MAIN][index=1]/attenuation-db",
                    ],
                ),
            ],
            body=[
                "FOR    ${path}    IN    @{paths}",
                "    ${before}=    IT COMMON - Gnmi Get And Return    ${path}",
                "END",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "FOR    ${path}    IN    @{paths}",
                "    ${after}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    ${path}",
                "    Log    ${value}",
                "END",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 6",
                "Log    ${cli}",
                "Should Contain    ${cli}    US_LEGACY_ATT_BEFORE_LNA",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json",
                "Should Contain    ${json}    us_legacy_att_before_lna_attenuation_db",
            ],
        ),
    ],
)

S(
    "CF-048",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the US FDX output VCEQ over gNMI",
    doc="Modify the US_FDX_OUT_VCEQ rf-component with gNMI and read the value "
        "back (User Guide 9.2.2).",
    cases=[
        C(
            "SET the US FDX output VCEQ over gNMI",
            doc=[
                "Step 1. GET the US FDX equalization",
                "Step 2. SET the value",
                "Step 3. GET it again and compare with sc_rfboard_cli",
            ],
            tags=["GNMI", "CLI", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/rf-components/us-fdx-equalization-db:::float:::9.5",
                    ],
                ),
                ("paths", ["/rf-components/us-fdx-equalization-db"]),
            ],
            body=[
                "FOR    ${path}    IN    @{paths}",
                "    ${before}=    IT COMMON - Gnmi Get And Return    ${path}",
                "END",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "FOR    ${path}    IN    @{paths}",
                "    ${after}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    ${path}",
                "    Log    ${value}",
                "END",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_var_tilt 3",
                "Log    ${cli}",
                "Should Contain    ${cli}    US_FDX_OUT_VCEQ",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json",
                "Should Contain    ${json}    us_fdx_out_vceq_tilt_db",
            ],
        ),
    ],
)

S(
    "CF-049",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the US FDX output attenuation over gNMI",
    doc="Modify the US_FDX_OUT_ATT rf-component with gNMI and read the value "
        "back (User Guide 9.2.2).",
    cases=[
        C(
            "SET the US FDX output attenuation over gNMI",
            doc=[
                "Step 1. GET the US FDX attenuation",
                "Step 2. SET the value",
                "Step 3. GET it again and compare with sc_rfboard_cli",
            ],
            tags=["GNMI", "CLI", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/rf-components/us-fdx-attenuation-db:::float:::18.5",
                    ],
                ),
                ("paths", ["/rf-components/us-fdx-attenuation-db"]),
            ],
            body=[
                "FOR    ${path}    IN    @{paths}",
                "    ${before}=    IT COMMON - Gnmi Get And Return    ${path}",
                "END",
                "${set}=    IT COMMON - Gnmi Set And Return    ${updates}",
                "Log    ${set}",
                "Should Contain    ${set}    UPDATE",
                "FOR    ${path}    IN    @{paths}",
                "    ${after}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    ${path}",
                "    Log    ${value}",
                "END",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_attenuation 5",
                "Log    ${cli}",
                "Should Contain    ${cli}    US_FDX_OUT_ATT",
                "${json}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_nonvol/rfboard_data.json",
                "Should Contain    ${json}    us_fdx_out_att_attenuation_db",
            ],
        ),
    ],
)

S(
    "CF-050",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Set the north port switch path over gNMI",
    doc="Get and set the np_monitor_input over gNMI (User Guide 9.2.2).",
    cases=[
        C(
            "SET the north port switch path over gNMI",
            doc=[
                "Step 1. GET the switch path",
                "Step 2. SET it to upstream and then to downstream",
                "Step 3. Compare the result with sc_rfboard_cli",
            ],
            tags=["GNMI", "CLI", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "updates",
                    [
                        "/rf-components/north-port-switch-path:::string:::NP_SWITCH_UPSTREAM",
                        "/rf-components/north-port-switch-path:::string:::NP_SWITCH_DOWNSTREAM",
                    ],
                ),
                ("paths", ["/rf-components/north-port-switch-path"]),
            ],
            body=[
                "${before}=    IT COMMON - Gnmi Get And Return    /rf-components/north-port-switch-path",
                "${set_up}=    IT COMMON - Gnmi Set And Return    ${{['/rf-components/north-port-switch-path:::string:::NP_SWITCH_UPSTREAM']}}",
                "Log    ${set_up}",
                "${set_down}=    IT COMMON - Gnmi Set And Return    ${{['/rf-components/north-port-switch-path:::string:::NP_SWITCH_DOWNSTREAM']}}",
                "Log    ${set_down}",
                "Should Contain    ${set_down}    UPDATE",
                "${after}=    IT COMMON - Gnmi Get And Return    /rf-components/north-port-switch-path",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    /rf-components/north-port-switch-path",
                "Log    ${value}",
                "${cli}=    IT COMMON - Run Dut Command And Return    sc_rfboard_cli get_np_monitor_input",
                "Log    ${cli}",
                "Should Contain    ${cli}    downstream",
            ],
        ),
    ],
)

S(
    "CF-051",
    bench=True,
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="The firmware upgrade over gNMI",
    doc="Send a SET request to perform a firmware upgrade through the "
        "software-upgrade tree (User Guide 9.18). The upgrade itself is a step "
        "of the bench procedure, so the suite reads the tree and checks that "
        "every update type is accepted.",
    cases=[
        C(
            "GET the software upgrade tree",
            doc=[
                "Step 1. GET software-upgrade",
                "Step 2. The answer has to hold the fields of the upgrade",
            ],
            tags=["GNMI"],
            log="1_get.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    software-upgrade",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    software-upgrade",
                "Log    ${value}",
            ],
        ),
        C(
            "Check that every update type is accepted",
            doc=[
                "Step 1. SET every update type of the User Guide 9.18.2 and read it back",
                "Step 2. The update type of the answer has to be the one that was set",
            ],
            tags=["GNMI", "WRITE"],
            log="2_update_types.log",
            vars=[
                (
                    "types",
                    [
                        "UPDATE_PUSH_ONLY",
                        "UPDATE_ROLL_BACK",
                        "UPDATE_STAGE_ONLY",
                        "UPDATE_ACTIVATE",
                        "UPDATE_DEACTIVATE",
                    ],
                ),
            ],
            body=[
                "FOR    ${type}    IN    @{types}",
                "    ${update}=    Catenate    /software-upgrade/update-type:::string:::    ${type}",
                "    ${set}=    IT COMMON - Gnmi Set And Return    ${{[$update]}}",
                "    Log    ${set}",
                "    Should Contain    ${set}    UPDATE",
                "    ${after}=    IT COMMON - Gnmi Get And Return    software-upgrade",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${after}    software-upgrade",
                "    ${current}=    IT COMMON - Get Dict Field    ${value}    update-type",
                "    Should Be Equal    ${current}    ${type}",
                "END",
            ],
        ),
    ],
)

S(
    "CF-052",
    bench=True,
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="Reboot the DUT over gNMI",
    doc="Reboot the device with a gNMI SET (User Guide 9.17). The reboot is a "
        "step of the bench procedure, so the suite sends the request and reads "
        "the system status afterwards.",
    cases=[
        C(
            "Read the system status before the reset",
            doc=[
                "Step 1. GET system-status",
                "Step 2. The answer has to hold the reboot info",
            ],
            tags=["GNMI"],
            log="1_status.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    system-status",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    system-status",
                "Log    ${value}",
            ],
        ),
    ],
)

S(
    "CF-053",
    sheet="CUST_FACING",
    area=GNMI_TESTS,
    comment="The gNMI containers that have no test case of their own",
    doc="Verify the gNMI containers that have no dedicated test case, "
        "focusing on the field semantics (User Guide 9.5, 9.6, 9.7, 9.8, "
        "9.13, 9.14, 9.15, 9.17).",
    cases=[
        C(
            "GET the twelve containers that have no test case of their own",
            doc=[
                "Step 1. GET every container",
                "Step 2. Every answer has to hold a value",
            ],
            tags=["GNMI"],
            log="1_containers.log",
            vars=[
                (
                    "paths",
                    [
                        "wbfft-capture",
                        "north-port-status",
                        "south-port-status",
                        "north-port-monitor-status",
                        "system-status",
                        "extended-upstream-spectrum-status",
                        "fallback-status",
                        "segment-allocation",
                        "ds-monitor-data",
                        "configuration-status",
                        "configuration-status/spectrum-state",
                    ],
                ),
            ],
            body=[
                # Every container is read, so that the report names all the
                # ones the server does not have and not only the first one.
                "@{missing}=    Create List",
                "FOR    ${path}    IN    @{paths}",
                "    ${response}=    IT COMMON - Gnmi Get And Return    ${path}",
                "    ${value}=    IT COMMON - Gnmi Get Leaf Value Or Default    ${response}    ${path}    ${NONE}",
                "    IF    $value is None",
                "        Append To List    ${missing}    ${path}",
                "    ELSE",
                "        Log    ${value}",
                "        Should Not Be Equal    ${value}    ${EMPTY}",
                "    END",
                "END",
                "IF    ${missing}",
                "    Fail    The gNMI server does not have these containers: ${missing}",
                "END",
            ],
        ),
        C(
            "Check the spectrum state of the configuration status",
            doc=[
                "Step 1. GET configuration-status/spectrum-state",
                "Step 2. The value has to be one of the four known states",
            ],
            tags=["GNMI"],
            log="2_spectrum_state.log",
            vars=[
                (
                    "states",
                    ["MID_SPLIT", "FDX_PENDING", "FDX_COARSE", "FDX_FINE"],
                ),
            ],
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    configuration-status/spectrum-state",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    configuration-status/spectrum-state",
                "Log    ${value}",
                "IT COMMON - Value Should Be One Of    ${value}    ${states}",
            ],
        ),
    ],
)

S(
    "CF-054",
    sheet="CUST_FACING",
    area=GRPC_TESTS,
    comment="The WBFFT capture and the hardware installation over gRPC",
    doc="The template holds two content blocks under this id: the WBFFT "
        "capture over gRPC and the three steps of the hardware installation. "
        "Both of them are two test cases of this suite.",
    vars=[
        ("wbfft_proto", "wbfft_capture.proto"),
        ("hw_proto", "hw_installation.proto"),
    ],
    cases=[
        C(
            "Run the WBFFT capture over gRPC",
            doc=[
                "Step 1. Call GetWbfftCapture with the capture configuration",
                "Step 2. The answer has to hold the results of the capture",
            ],
            tags=["GRPC"],
            log="1_wbfft.log",
            vars=[
                (
                    "payload",
                    '{"wbfft_capture_configuration": {'
                    '"start_frequency_hz": 0, "end_frequency_hz": 1218000000, '
                    '"fft_size": 16384, "sampling_rate_hz": 1647000000, '
                    '"output_format": "OutputFormat_FreqDomainPower", '
                    '"windowing_mode": "WindowingMode_None", '
                    '"averaging_mode": "AveragingMode_Time", "output_scale": 6, '
                    '"aggregation_period_ms": 200, "sample_point": "SamplePoint_NpD", '
                    '"reset_averaging_between_measurements": false, '
                    '"measurement_count": 0, "measurement_rate_ms": 1, '
                    '"total_measurement_duration_ms": 200}}',
                ),
            ],
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${wbfft_proto}    gnoi.wbfft.v1.WbfftCapture/GetWbfftCapture    ${payload}    timeout=120",
                "Log    ${response}",
            ],
        ),
        C(
            "Read the pre-alignment status over gRPC",
            doc=[
                "Step 1. Call GetPreAlignmentStatus",
                "Step 2. The answer has to hold the eCM registration and the input power",
                "Step 3. Compare the input power with the north port status",
            ],
            tags=["GRPC", "CLI"],
            log="2_pre_alignment.log",
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${hw_proto}    gnoi.hw_installation.v1.HwInstallation/GetPreAlignmentStatus",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "${registration}=    IT COMMON - Grpc Get Field    ${response}    ecmRegistration",
                "Should Be True    ${registration}",
                "${tcp}=    IT COMMON - Grpc Get Field    ${response}    northPortInputTcp",
                "Log    ${tcp}",
                "${pab}=    IT COMMON - Run Dut Command And Return    sc_cli get_pab_status",
                "Log    ${pab}",
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_north_port_status 0",
                "${input}=    IT COMMON - Get Cli Field    ${status}    rx_adc_input_power_dbmv_tcp",
                "Log    ${input}",
            ],
        ),
        C(
            "Set the initial configuration over gRPC",
            doc=[
                "Step 1. Call SetInitialConfiguration",
                "Step 2. The answer has to report success",
            ],
            tags=["GRPC", "WRITE"],
            log="3_initial_configuration.log",
            vars=[
                (
                    "payload",
                    '{"spectrum": {"downstream_begin_hz": 108000000, '
                    '"downstream_end_hz": 1218000000, "legacy_upstream_begin_hz": 5000000, '
                    '"legacy_upstream_end_hz": 85000000, "extended_upstream_begin_hz": 108000000, '
                    '"extended_upstream_end_hz": 684000000, '
                    '"description": "Default_Genesis_DDD_1.2GHz_Test_by_User", '
                    '"subband_modes": [3, 3, 3]}, '
                    '"downstream_profile": [{"port_type": 1, '
                    '"description": "North port downstream profile", '
                    '"start_frequency_hz": 120000000, "end_frequency_hz": 1002000000, '
                    '"start_downstream_psd_dbmv_per_6mhz": 36.8, '
                    '"end_downstream_psd_dbmv_per_6mhz": 45.0}, '
                    '{"port_type": 2, "description": "South port downstream profile", '
                    '"start_frequency_hz": 120000000, "end_frequency_hz": 1002000000, '
                    '"start_downstream_psd_dbmv_per_6mhz": 36.8, '
                    '"end_downstream_psd_dbmv_per_6mhz": 45.0}], '
                    '"upstream_profile": [{"port_type": 1, '
                    '"target_receive_power_dbmv_per_6_4_mhz": 6.0}, '
                    '{"port_type": 2, "target_receive_power_dbmv_per_6_4_mhz": 6.0}], '
                    '"north_port_afe_backoff": 3.0, "north_port_target_tcp": 35.0, '
                    '"north_port_is_threshold": 4.0}',
                ),
            ],
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${hw_proto}    gnoi.hw_installation.v1.HwInstallation/SetInitialConfiguration    ${payload}",
                "IT COMMON - Grpc Should Succeed    ${response}",
            ],
        ),
        C(
            "Start the calibration over gRPC",
            doc=[
                "Step 1. Call StartCalibration",
                "Step 2. The stream has to report the progress of the stages",
            ],
            tags=["GRPC", "WRITE"],
            log="4_start_calibration.log",
            body=[
                # StartCalibration is a streaming call: it answers with one
                # JSON document per message, the progress of a stage and the
                # failure at the end of it.
                "${documents}=    IT COMMON - Grpcurl And Return Json List    ${hw_proto}    gnoi.hw_installation.v1.HwInstallation/StartCalibration    ${EMPTY}    timeout=600",
                "Log    ${documents}",
                "${stages}=    Evaluate    [d['progress']['status'] for d in $documents if isinstance(d, dict) and 'progress' in d]    modules=builtins",
                "Log    The reported stages are ${stages}",
                "Should Not Be Empty    ${stages}",
                "${failures}=    Evaluate    [d['failure'] for d in $documents if isinstance(d, dict) and 'failure' in d]    modules=builtins",
                "IF    $failures",
                "    Fail    The calibration failed: ${failures}",
                "END",
            ],
        ),
    ],
)

S(
    "CF-055",
    sheet="CUST_FACING",
    area=GRPC_TESTS,
    comment="The US FDX DAC power mode over gRPC",
    doc="Verify that the gRPC US FDX DAC service can read and set the DAC "
        "power mode (User Guide 12.1.5).",
    vars=[
        ("proto", "us_fdx_dac.proto"),
        ("get_method", "gnoi.us_fdx_dac.v1.UsFdxDacController/GetUsFdxDacPowerModeVolatile"),
        ("set_method", "gnoi.us_fdx_dac.v1.UsFdxDacController/SetUsFdxDacPowerModeVolatile"),
    ],
    cases=[
        C(
            "GET the DAC power mode over gRPC",
            doc=[
                "Step 1. Call GetUsFdxDacPowerModeVolatile",
                "Step 2. The answer has to hold the mode",
            ],
            tags=["GRPC"],
            log="1_get.log",
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "Log    ${response}",
            ],
        ),
        C(
            "SET the DAC power mode over gRPC",
            doc=[
                "Step 1. SET the mode to ENABLED",
                "Step 2. SET the mode to DISABLED",
                "Step 3. GET the mode again",
            ],
            tags=["GRPC", "WRITE"],
            log="2_set.log",
            vars=[
                ("enabled", '{"mode": "ENABLED"}'),
                ("disabled", '{"mode": "DISABLED"}'),
            ],
            body=[
                "${on}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${enabled}",
                "Log    ${on}",
                "${off}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${set_method}    ${disabled}",
                "Log    ${off}",
                "${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "Log    ${after}",
            ],
        ),
    ],
)

S(
    "CF-056",
    sheet="CUST_FACING",
    area=DS_TRACKER,
    comment="The DS Tracker configuration and its monitor data",
    doc="Verify the DS Tracker configuration, its process, its gNMI monitor "
        "data and the periodic syslog (User Guide 13). The upgrade of the "
        "binary needs a server and is a step of the bench procedure.",
    vars=[
        ("proto", "ds_periodic_maintanence.proto"),
        ("method", "gnoi.ds_periodic_maintanence.v1.DownstreamPeriodicMaintanence/SetDpmConfiguration"),
        ("get_method", "gnoi.ds_periodic_maintanence.v1.DownstreamPeriodicMaintanence/GetDpmConfiguration"),
    ],
    cases=[
        C(
            "Set the DS Tracker configuration over gRPC",
            doc=[
                "Step 1. Call SetDpmConfiguration",
                "Step 2. The answer has to report success",
                "Step 3. GET the configuration again",
            ],
            tags=["GRPC", "WRITE"],
            log="1_set.log",
            vars=[
                (
                    "payload",
                    '{"enabled": true, "configuration": {"period_in_seconds": 3600, '
                    '"number_of_wbfft_captures": 200, "number_of_aggregation": 60, '
                    '"startup_delay_seconds": 0}, '
                    '"wbfft_capture_configuration": {"description": "Sample FFT config", '
                    '"start_frequency_hz": 108000000, "end_frequency_hz": 1218000000, '
                    '"fft_size": 16384, "sampling_rate_hz": 1647000000, '
                    '"output_format": "OutputFormat_FreqDomainPower", '
                    '"windowing_mode": "WindowingMode_None", '
                    '"averaging_mode": "AveragingMode_Time", "output_scale": 6, '
                    '"aggregation_period_ms": 200, "sample_point": "SamplePoint_NpD", '
                    '"reset_averaging_between_measurements": false, '
                    '"measurement_count": 0, "measurement_rate_ms": 1, '
                    '"total_measurement_duration_ms": 200}, '
                    '"adjustment_threshold_range": [{"min_value": 188946946, '
                    '"max_value": 381364161}]}',
                ),
            ],
            body=[
                "${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}",
                "IT COMMON - Grpc Should Succeed    ${response}",
                "${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}",
                "IT COMMON - Grpc Should Succeed    ${after}",
                "${enabled}=    IT COMMON - Grpc Get Field    ${after}    enabled",
                "Should Be True    ${enabled}",
            ],
        ),
        C(
            "Read the monitor data of the DS Tracker over gNMI",
            doc=[
                "Step 1. GET ds-monitor-data",
                "Step 2. The answer has to hold the state of the tracker",
            ],
            tags=["GNMI"],
            log="2_monitor.log",
            body=[
                "${response}=    IT COMMON - Gnmi Get And Return    ds-monitor-data",
                "${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ds-monitor-data",
                "Log    ${value}",
            ],
        ),
        C(
            "Check the process of the DS Tracker and its syslog",
            doc=[
                "Step 1. Look for the tracker process",
                "Step 2. Look for the periodic telemetry in the syslog",
            ],
            tags=["FILE"],
            log="3_process.log",
            body=[
                "${process}=    IT COMMON - Run Dut Command And Return    ps aux | grep -i track",
                "Log    ${process}",
                "${syslog}=    IT COMMON - Run Dut Command And Return    cat /dev/shm/syslog | grep -i 'cached DS telemetry'",
                "Log    ${syslog}",
            ],
        ),
    ],
)

S(
    "CF-057",
    sheet="CUST_FACING",
    area=SSH,
    comment="The login banner",
    doc="Verify that the SSH login banner can be configured and removed "
        "(User Guide 14.1).",
    cases=[
        C(
            "Configure the login banner and remove it again",
            doc=[
                "Step 1. Write the banner text and end it with a line that holds only /end",
                "Step 2. Check that the banner was configured",
                "Step 3. Open a new session and check that the banner is in it",
                "Step 4. Remove the banner again",
                "Step 5. Open a new session and check that the banner is gone",
            ],
            tags=["CLI", "WRITE"],
            log="1_banner.log",
            body=[
                # The banner view of the clish has no prompt of its own: it
                # asks for the text and waits for the line that holds only
                # "/end", so the text is sent without waiting for a prompt.
                "${enter}=    IT COMMON - Run Fdx Command And Return Buffer    configure banner login    timeout=5",
                "Log    ${enter}",
                "Should Contain    ${enter}    Enter TEXT message",
                "${line1}=    IT COMMON - Run Fdx Command And Return Buffer    This is the login banner of the IT suite    timeout=5",
                "Log    ${line1}",
                "${end}=    IT COMMON - Run Fdx Command And Return    /end",
                "Log    ${end}",
                "Should Contain    ${end}    Login banner configured.",
                # The banner shows up in the banner of a new session.
                "${banner}=    IT COMMON - Get Dut Login Banner",
                "Log    ${banner}",
                "Should Contain    ${banner}    This is the login banner of the IT suite",
                "${remove}=    IT COMMON - Run Fdx Command And Return    configure banner login no",
                "Log    ${remove}",
                "Should Contain    ${remove}    Login banner cleared.",
                "${after}=    IT COMMON - Get Dut Login Banner",
                "Log    ${after}",
                "Should Not Contain    ${after}    This is the login banner of the IT suite",
            ],
        ),
    ],
)

S(
    "CF-058",
    bench=True,
    sheet="CUST_FACING",
    area=SSH,
    comment="The SSH authentication settings and the idle timeout",
    doc="Verify the SSH password authentication, the public key authentication "
        "and the idle timeout (User Guide 14.2). The suite reads the settings "
        "and the idle timeout; it does not disable the password "
        "authentication, because that would take the bench away.",
    cases=[
        C(
            "Read the authentication settings and the idle timeout",
            doc=[
                "Step 1. Run debug ssh show auths",
                "Step 2. Run debug ssh show idle-timeout",
            ],
            tags=["CLI"],
            log="1_settings.log",
            body=[
                "${auths}=    IT COMMON - Run Fdx Command And Return    debug ssh show auths",
                "Log    ${auths}",
                "Should Not Be Equal    ${auths}    ${EMPTY}",
                "${timeout}=    IT COMMON - Run Fdx Command And Return    debug ssh show idle-timeout",
                "Log    ${timeout}",
            ],
        ),
    ],
)

S(
    "CF-059",
    sheet="CUST_FACING",
    area=SSH,
    comment="The user and the key management",
    doc="Verify the user management, the client public key management, the "
        "host public key management and the live sessions (User Guide 14.3, "
        "14.4, 14.5, 14.6).",
    cases=[
        C(
            "Add a user and remove it again",
            doc=[
                "Step 1. Create the user test3 with a password",
                "Step 2. Read the configured users",
                "Step 3. Remove the user again",
            ],
            tags=["CLI", "WRITE"],
            log="1_user.log",
            body=[
                # A user of a previous run is removed first, so that the table
                # of the DUT has room for the one of this case.
                "${clean}=    IT COMMON - Run Fdx Command And Return    configure username test3 no",
                "Log    ${clean}",
                "${add}=    IT COMMON - Run Fdx Command And Return    configure username test3 password test3",
                "Log    ${add}",
                "${users}=    IT COMMON - Run Fdx Command And Return    debug login show configured-users-db",
                "Log    ${users}",
                # The name is looked for with the comma behind it: the table
                # holds the names test1 to test30, and "test3" is the start of
                # "test30" as well.
                "Should Contain    ${users}    user=test3,",
                "${remove}=    IT COMMON - Run Fdx Command And Return    configure username test3 no",
                "Log    ${remove}",
                "${after}=    IT COMMON - Run Fdx Command And Return    debug login show configured-users-db",
                "Should Not Contain    ${after}    user=test3,",
            ],
        ),
        C(
            "Read the live sessions",
            doc=[
                "Step 1. Run show users",
                "Step 2. The answer has to list the live sessions",
            ],
            tags=["CLI"],
            log="2_sessions.log",
            body=[
                "${out}=    IT COMMON - Run Fdx Command And Return    show users",
                "Log    ${out}",
                "Should Not Be Equal    ${out}    ${EMPTY}",
            ],
        ),
    ],
)

S(
    "CF-060",
    sheet="CUST_FACING",
    area=SSH,
    comment="The SSH login to the embedded cable modem",
    doc="Verify the standard operating procedure to log in to the embedded "
        "cable modem from the eAMP (User Guide 14.7).",
    cases=[
        C(
            "Check that the embedded cable modem answers",
            doc=[
                "Step 1. Read the registration status of the modem",
                "Step 2. The modem has to be operational",
                "Step 3. Check that the modem answers on its management address",
            ],
            tags=["CLI"],
            log="1_ecm.log",
            body=[
                "${status}=    IT COMMON - Run Dut Command And Return    sc_cli get_snmp_cm_status",
                "Log    ${status}",
                "Should Contain    ${status}    eCM is OPERATIONAL",
                "${ping}=    IT COMMON - Run Dut Command And Return    ping -c 2 -W 3 172.31.255.45    timeout=30",
                "Log    ${ping}",
            ],
        ),
    ],
)

S(
    "CF-061",
    sheet="CUST_FACING",
    area=MSC,
    comment="The Sercomm master control commands",
    doc="Verify the nine sc_msc_cli commands that arbitrate the RF board "
        "controller (User Guide 10.14).",
    cases=[
        C(
            "Read the MSC state, the controller, the statistics and the timeout",
            doc=[
                "Step 1. Read the MSC state",
                "Step 2. Read the MSC controller",
                "Step 3. Read the MSC statistics",
                "Step 4. Read the MGC timeout",
                "Step 5. Read the bypass controller decision",
            ],
            tags=["CLI"],
            log="1_read.log",
            body=[
                "${state}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_state",
                "${controller}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_controller",
                "${stats}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_msc_stats",
                "${timeout}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_mgc_timeout",
                "${bypass}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_bypass_controller_decision",
                "Log    ${state}",
                "Log    ${controller}",
                "Log    ${stats}",
                "Log    ${timeout}",
                "Log    ${bypass}",
                "Should Contain    ${state}    MSC state:",
                "Should Contain    ${controller}    MSC controller:",
                "Should Contain    ${stats}    successful_forwards",
                "Should Contain    ${timeout}    MGC timeout:",
                "Should Contain    ${bypass}    Bypass controller decision:",
            ],
        ),
        C(
            "Set the MGC timeout and put it back",
            doc=[
                "Step 1. Read the MGC timeout",
                "Step 2. Set it to 300 s and read it back",
                "Step 3. Put the original value back",
            ],
            tags=["CLI", "WRITE"],
            log="2_timeout.log",
            body=[
                "${before}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_mgc_timeout",
                "${old}=    IT COMMON - Get Cli Field    ${before}    MGC timeout",
                "${set}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_mgc_timeout 300",
                "${after}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_mgc_timeout",
                "Log    ${after}",
                "Should Contain    ${after}    300",
                "${back}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_mgc_timeout ${old}",
            ],
        ),
        C(
            "Toggle the bypass controller decision",
            doc=[
                "Step 1. Set the bypass controller decision to 1 and read it back",
                "Step 2. Set it back to 0 and read it back",
            ],
            tags=["CLI", "WRITE"],
            log="3_bypass.log",
            body=[
                "${on}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_bypass_controller_decision 1",
                "${on_state}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_bypass_controller_decision",
                "Log    ${on_state}",
                "Should Contain    ${on_state}    enabled",
                "${off}=    IT COMMON - Run Dut Command And Return    sc_msc_cli set_bypass_controller_decision 0",
                "${off_state}=    IT COMMON - Run Dut Command And Return    sc_msc_cli get_bypass_controller_decision",
                "Log    ${off_state}",
                "Should Contain    ${off_state}    disabled",
            ],
        ),
    ],
)
