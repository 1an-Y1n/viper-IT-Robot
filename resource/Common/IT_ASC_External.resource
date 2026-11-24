*** Keywords ***
IT ASC EXTERNAL - Set North Port Input Delta
    [Documentation]    Set the north port input level relative to the calibration baseline, in dB.
    ...    Use external signal equipment, not RF board commands; save the original state for restoration.
    [Arguments]    ${delta_db}
    Fail    North port signal control is not implemented; connect a bench adapter first.

IT ASC EXTERNAL - Restore North Port Signal
    [Documentation]    Restore the input signal state saved by the north port adjustment adapter.
    Fail    North port signal restoration is not implemented; connect a bench adapter first.
