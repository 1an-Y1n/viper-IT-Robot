*** Settings ***
# @author: Ian Yin
# @updated: 2026-11-19
# @comment: the checks that tell whether the bench is ready for a campaign
Documentation    The checks of the environment of the IT campaign.
...
...              Every check is a keyword of its own and every check answers
...              one question, so that the report of the run says which one
...              failed and what to do about it. The campaign runs them before
...              the first test item, because a bench that is not ready shows
...              up as a test failure in the middle of a campaign, where it
...              costs the most time.
Library    ../../lib/Viper/ViperFirmware.py    WITH NAME    ViperFirmware
Library    OperatingSystem
Library    String
Library    Collections
# The keywords that talk to the DUT: the CLI, the gNMI and the gRPC calls.
Resource    IT_Common.resource

*** Keywords ***
IT ENV - The Firmware Images Are In The Local Directory
    [Documentation]    Check that the two images of the campaign are in the
    ...              local directory, and report how big they are.

    ...              The images are about 288 MB each and they are not in the
    ...              repository, so the campaign gets them from somewhere else
    ...              and drops them here.

    [Arguments]    ${images}=${EMPTY}
    IF    $images == '' or $images == []
        ${images}=    Create List    ${FW_IMAGE_NEW}    ${FW_IMAGE_OLD}
    END
    ${found}=    ViperFirmware.Local Images    ${FW_IMAGE_DIR}    ${images}
    ${names}=    Get Length    ${found}
    ${expected}=    Get Length    ${images}
    Should Be Equal As Integers    ${names}    ${expected}
    ...    msg=The firmware images are not all in ${FW_IMAGE_DIR}. The ones that are missing have to be put there before the campaign.
    RETURN    ${found}

IT ENV - The Firmware Images Are Uploaded To The Server
    [Documentation]    Put the images of the campaign on the firmware server.

    ...              The upload is a PUT to the very URL the DUT asks for, so
    ...              the image lands where the DUT looks for it.

    [Arguments]    ${files}=${EMPTY}
    IF    $files == '' or $files == []
        ${files}=    IT ENV - The Firmware Images Are In The Local Directory
    END
    ViperFirmware.Upload    ${FW_SERVER}    ${files}
    ...    ${FW_UPLOAD_USER}    ${FW_UPLOAD_PASSWORD}

IT ENV - The Firmware Images Are On The Server
    [Documentation]    Check that the DUT finds the images on the server.

    ...              The request is the one the AMP makes itself before it
    ...              starts the download, so a green check here means the
    ...              upgrade will find its image.

    [Arguments]    ${images}=${EMPTY}
    IF    $images == '' or $images == []
        ${images}=    Create List    ${FW_IMAGE_NEW}    ${FW_IMAGE_OLD}
    END
    FOR    ${image}    IN    @{images}
        IT COMMON - Firmware Image Should Be On Server    ${image}
    END

IT ENV - The Dut Is The Expected Unit
    [Documentation]    Check the serial number of the DUT.

    ...              The bench holds more than one unit and the address of a
    ...              unit is not a fixed property of it, so a campaign that
    ...              runs on the wrong unit wastes the whole run.

    ${response}=    IT COMMON - Gnmi Get And Return    amp-identification
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    amp-identification
    ${serial}=    IT COMMON - Get Dict Field    ${value}    serial-number
    Should Be Equal    ${serial}    ${DUT_IT_SERIAL}
    ...    msg=This is not the unit of the campaign. The expected serial is ${DUT_IT_SERIAL}, this one is ${serial}.

IT ENV - The Dut Reports Its Firmware Version
    [Documentation]    Read the firmware version of the DUT.

    ...              The result of the campaign says which image it ran
    ...              against, so the version is read before the first item.

    ${version}=    IT COMMON - Run Fdx Command And Return    show version
    Log    ${version}
    Should Contain    ${version}    Software Version
    RETURN    ${version}

IT ENV - The Dut Sees The Firmware Server
    [Documentation]    Check that the DUT can reach the firmware server.

    ...              The DUT pulls the image over the management port, so it
    ...              has to reach the server from there.

    ${ping}=    IT COMMON - Run Dut Root Command And Return
    ...    ping -c 2 -W 3 ${FW_SERVER}
    Should Contain    ${ping}    0% packet loss
    ...    msg=The DUT cannot reach the firmware server ${FW_SERVER}. The answer was:\n${ping}
