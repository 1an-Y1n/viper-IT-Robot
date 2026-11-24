*** Settings ***
# @author: Ian Yin
# @version: V1.0.0
# @updated: 2026-11-18
# @comment: shared keywords for the IT suites built from the LE IT test template
#
# ---------------------------------------------------------------------------
# How to write assertions in the IT suites
#
# Robot Framework processes escape sequences in every string literal, and an
# unknown escape loses its backslash: "\s" becomes "s", "\t" becomes a real
# tab. A regex written straight into a test file therefore breaks in a way
# that is invisible until the assertion silently matches the wrong thing.
#
# So the vocabulary below is deliberately regex free: the suites compare
# labelled fields ("key : value") and plain substrings, and every regexp
# lives here in the resource where its escaping is under control.
#
# When a regexp really is needed, write it with character classes only
# ("[ ]*" for blanks, "[0-9]+" for digits) or double the backslash
# ("\\s" reaches Python as "\s").
#
# The DUT side of the automation:
#   - SSH_IT_ROOT   the linux shell of the eAMP, where sc_cli and friends live
#   - SSH_IT        the clish shell (FDX-AMP>$), for the clish commands
#   - GNMI_IT       a non interactive exec channel on the DUT, used to run
#                   gnmic and grpcurl against the DUT's own loopback servers
# ---------------------------------------------------------------------------
Library    OperatingSystem
Library    String
Library    Collections
# The keywords below drive the DUT over its own management SSH, so this
# resource imports the libraries it calls. The path is relative to this file,
# which sits in resource/Common, two levels below the project root.
Library    ../../lib/Viper/ViperSSH.py    WITH NAME    SSH_IT
Library    ../../lib/Viper/ViperSSH.py    WITH NAME    SSH_IT_ROOT
Library    ../../lib/Viper/ViperSSH.py    WITH NAME    SSH_IT_BANNER
Library    ../../lib/Viper/ViperGnmi.py    WITH NAME    GNMI_IT
# The paths of a gNMI answer are not the paths of the request, e.g. gnmic
# writes them without the leading slash and holds the values under the path
# without its key selectors. GnmiPath resolves a path inside an answer.
Library    ../../lib/Viper/GnmiPath.py    WITH NAME    GnmiPath
Library    ../../lib/Viper/GrpcJson.py    WITH NAME    GrpcJson

*** Variables ***
# The gNMI and gRPC servers both listen on the DUT's loopback. gnmic and
# grpcurl run on the DUT as well, so these two are one and the same address.
${GNMI_TARGET}    127.0.0.1:9339
${GRPC_TARGET}    127.0.0.1:9338
# The name of the log file of the test case that is running. Every IT test
# case declares one with "VAR ${sc_log}    <name>", and the keywords below
# write their output into it, so the commands of one case end up in one file
# instead of in the log of the whole suite. An empty name means "no name of
# its own", and the output goes into the log of the session instead.
${sc_log}    ${EMPTY}
# How long a state change is given to land on the DUT.
${IT_WAIT_DEFAULT}    60
${IT_POLL_DEFAULT}    5
# The login shell of the DUT is clish. A command that comes in over a non
# interactive channel is handed over to sh with a fixed buffer, and a command
# longer than this is cut, which the shell then reports as a syntax error.
# Measured on the DUT: 225 characters still work, 226 do not.
${IT_EXEC_MAX_LEN}    220

*** Keywords ***
# ---------------------------------------------------------------------------
# Running commands on the DUT
# ---------------------------------------------------------------------------
IT COMMON - Run Dut Command And Return
    [Documentation]    Run a command on the DUT's linux shell and return its output.

    ...              The command is sent through the ROOT level SSH session, so it
    ...              runs as root on the eAMP: the sc_cli / sc_rfboard_cli /
    ...              sc_amphal_cli / sc_msc_cli family all live there.

    ...              The buffer that comes back carries the echoed command as its
    ...              first line and the shell prompt as its last, so the payload
    ...              is cut out between them. A caller that wants the raw buffer
    ...              should use the SSH keyword directly.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}
    IF    $log_name is None or $log_name == ''
        ${buffer}=    SSH_IT_ROOT.Send And Return    ${cmd}    resp_timeout=${timeout}
    ELSE
        ${buffer}=    SSH_IT_ROOT.Send And Return    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}
    END
    ${text}=    IT COMMON - Strip Command Echo    ${buffer}    ${cmd}
    RETURN    ${text}

IT COMMON - Run Fdx Command And Return
    [Documentation]    Run a clish command on the DUT and return its output.

    ...              The clish shell is the FDX level session, its prompt is
    ...              "FDX-AMP>$ ". The echoed command and the prompt are cut out
    ...              of the buffer the same way as on the ROOT session.

    ...              ${prompt} overrides the prompt the answer is waited for.
    ...              A command that enters a clish view answers with the prompt
    ...              of that view, e.g. "FDX-AMP(calibration)>$ ".

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}    ${prompt}=${NONE}
    IF    $prompt is None
        IF    $log_name is None or $log_name == ''
            ${buffer}=    SSH_IT.Send And Return    ${cmd}    resp_timeout=${timeout}
        ELSE
            ${buffer}=    SSH_IT.Send And Return    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}
        END
    ELSE
        IF    $log_name is None or $log_name == ''
            ${buffer}=    SSH_IT.Send And Return    ${cmd}    resp_timeout=${timeout}    prompt=${prompt}
        ELSE
            ${buffer}=    SSH_IT.Send And Return    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}    prompt=${prompt}
        END
    END
    ${text}=    IT COMMON - Strip Command Echo    ${buffer}    ${cmd}
    RETURN    ${text}

IT COMMON - Run Dut Hal Command And Return
    [Documentation]    Run a command in the Broadcom HAL of the DUT and return its output.

    ...              The HAL is not a program of its own on the DUT: it is the
    ...              Broadcom CLI that the AMP talks to over /tmp/brcmhal.sock.
    ...              It is reached from clish with "debug hal", and it takes the
    ...              prompt of clish away while it is there.

    ...              The HAL prints its prompt only after it gets a newline, so
    ...              the session has to be nudged with an empty line before the
    ...              prompt shows up. The SSH library does that on its own.

    ...              The HAL is left with Ctrl-D, the EOF that ends it, and the
    ...              prompt of clish comes back. The buffer is taken even when
    ...              the prompt did not come in time, so that a command that
    ...              hangs does not leave the session stuck in the HAL.

    [Arguments]    ${cmd}    ${timeout}=30    ${log_name}=${sc_log}
    SSH_IT.Ensure Level    HAL
    IF    $log_name is None or $log_name == ''
        ${buffer}=    SSH_IT.Send And Return Buffer    ${cmd}    resp_timeout=${timeout}
    ELSE
        ${buffer}=    SSH_IT.Send And Return Buffer    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}
    END
    SSH_IT.Ensure Level    FDX
    ${text}=    IT COMMON - Strip Command Echo    ${buffer}    ${cmd}
    RETURN    ${text}

IT COMMON - Fdx Enter View
    [Documentation]    Enter a clish view, e.g. the calibration view.

    ...              The command that enters the view answers with the prompt
    ...              of that view, so the prompt has to be given to the SSH
    ...              keyword, otherwise it waits for the top level prompt and
    ...              times out.

    ...              ${command} is what is sent ("configure ds-profile north")
    ...              and ${view} is the name of the view as it shows up in the
    ...              prompt ("ds-profile-north"). The two differ: the command
    ...              takes the port, the prompt takes it with a dash.

    [Arguments]    ${command}    ${view}    ${timeout}=15    ${log_name}=${sc_log}
    ${prompt}=    Catenate    SEPARATOR=    FDX-AMP(    ${view}    )>$
    ${text}=    IT COMMON - Run Fdx Command And Return    ${command}    ${timeout}    ${log_name}    ${prompt}
    RETURN    ${text}

IT COMMON - Fdx Exit View
    [Documentation]    Leave the clish view and go back to the top level.

    [Arguments]    ${view}    ${timeout}=15    ${log_name}=${sc_log}
    ${text}=    IT COMMON - Run Fdx Command And Return    exit    ${timeout}    ${log_name}    FDX-AMP>$
    RETURN    ${text}

IT COMMON - Run Fdx View Command And Return
    [Documentation]    Run a command inside a clish view, e.g. the calibration view.

    ...              ${view} is the name of the view as it shows up in the
    ...              prompt, e.g. "ds-profile-north". The prompt of the view is
    ...              "FDX-AMP(<view)>$ ", so the command has to be sent with
    ...              that prompt.

    [Arguments]    ${view}    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}
    ${prompt}=    Catenate    SEPARATOR=    FDX-AMP(    ${view}    )>$
    ${text}=    IT COMMON - Run Fdx Command And Return    ${cmd}    ${timeout}    ${log_name}    ${prompt}
    RETURN    ${text}

IT COMMON - Run Dut Exec Command And Return
    [Documentation]    Run a command through the non interactive gNMI session.

    ...              ViperGnmi opens an exec channel, so whatever is sent lands
    ...              on the SSH host, which is the DUT itself. This is how
    ...              gnmic and grpcurl are run on the DUT against its loopback
    ...              gNMI / gRPC servers.

    ...              gnmic reports a rejected request on stderr and still exits
    ...              with 0, so the two streams are merged here. A caller that
    ...              wants the error text of a negative case therefore sees it,
    ...              and a positive case is not satisfied by an error message
    ...              because the error text carries no success marker.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}
    ${full}=    Catenate    ${cmd}    2>&1
    ${length}=    Get Length    ${full}
    IF    $length > ${IT_EXEC_MAX_LEN}
        ${raw}=    IT COMMON - Run Dut Long Command And Return    ${full}    ${timeout}    ${log_name}
    ELSE
        IF    $log_name is None or $log_name == ''
            ${raw}=    GNMI_IT.Raw And Return    ${full}    resp_timeout=${timeout}
        ELSE
            ${raw}=    GNMI_IT.Raw And Return    ${full}    resp_timeout=${timeout}    log_name=${log_name}
        END
    END
    RETURN    ${raw}

IT COMMON - Run Dut Root Command And Return
    [Documentation]    Run a command on the linux shell of the DUT.

    ...              The login shell of the DUT is clish and it hands a
    ...              non interactive command over to sh with a fixed buffer,
    ...              see ${IT_EXEC_MAX_LEN}. On top of that clish wraps the
    ...              command in "sh -c \"...\"", so a command that carries
    ...              double quotes of its own, e.g. the JSON of a gRPC call,
    ...              is cut apart by the quoting.

    ...              The ROOT session is a real bash and it takes the whole
    ...              line, so a command that is long or that carries quotes is
    ...              sent there.

    ...              The answer is cut out between two markers, because the
    ...              terminal wraps the echo of a long command into several
    ...              lines. The markers are written as IT""_BEGIN so that the
    ...              echo of the command line does not hold the marker text
    ...              itself and a wrap cannot split it.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}
    ${line}=    Catenate    SEPARATOR=;    echo IT""_BEGIN    ${cmd}    echo IT""_END
    IF    $log_name is None or $log_name == ''
        ${buffer}=    SSH_IT_ROOT.Send And Return    ${line}    resp_timeout=${timeout}
    ELSE
        ${buffer}=    SSH_IT_ROOT.Send And Return    ${line}    resp_timeout=${timeout}    log_name=${log_name}
    END
    ${text}=    IT COMMON - Strip Command Echo    ${buffer}    ${line}
    ${parts}=    Evaluate    $text.split('IT_BEGIN')    modules=builtins
    ${body}=    Evaluate    $parts[-1].split('IT_END')[0]    modules=builtins
    RETURN    ${body}

IT COMMON - Run Dut Root Command And Return Buffer
    [Documentation]    Run a command on the linux shell and return what came
    ...              back, even when the prompt did not come in time.

    ...              A command that is slow on the DUT does not answer within
    ...              the timeout of one poll, e.g. "sc_amphal_cli
    ...              get_ecm_status" while the eCM is ranging. A caller that
    ...              polls for minutes must not lose the whole wait because of
    ...              one slow answer, so the buffer is handed back as it is.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}
    ${line}=    Catenate    SEPARATOR=;    echo IT""_BEGIN    ${cmd}    echo IT""_END
    IF    $log_name is None or $log_name == ''
        ${buffer}=    SSH_IT_ROOT.Send And Return Buffer    ${line}    resp_timeout=${timeout}
    ELSE
        ${buffer}=    SSH_IT_ROOT.Send And Return Buffer    ${line}    resp_timeout=${timeout}    log_name=${log_name}
    END
    ${text}=    IT COMMON - Strip Command Echo    ${buffer}    ${line}
    ${parts}=    Evaluate    $text.split('IT_BEGIN')    modules=builtins
    ${body}=    Evaluate    $parts[-1].split('IT_END')[0]    modules=builtins
    RETURN    ${body}

IT COMMON - Run Dut Long Command And Return
    [Documentation]    Run a command that is too long for the exec channel.

    ...              See IT COMMON - Run Dut Root Command And Return, the
    ...              command goes over the ROOT session of the DUT.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}
    ${text}=    IT COMMON - Run Dut Root Command And Return    ${cmd}    ${timeout}    ${log_name}
    RETURN    ${text}

IT COMMON - Run Dut Command And Return Raw
    [Documentation]    Run a command on the DUT and return the raw buffer.

    ...              The raw buffer carries the echoed command and the prompt,
    ...              which is what a caller needs when it looks for the prompt
    ...              itself, e.g. to check which shell it is in.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}
    IF    $log_name is None or $log_name == ''
        ${buffer}=    SSH_IT_ROOT.Send And Return    ${cmd}    resp_timeout=${timeout}
    ELSE
        ${buffer}=    SSH_IT_ROOT.Send And Return    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}
    END
    RETURN    ${buffer}

IT COMMON - Run Fdx Command And Return Raw
    [Documentation]    Run a clish command on the DUT and return the raw buffer.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}    ${prompt}=${NONE}
    IF    $prompt is None
        IF    $log_name is None or $log_name == ''
            ${buffer}=    SSH_IT.Send And Return    ${cmd}    resp_timeout=${timeout}
        ELSE
            ${buffer}=    SSH_IT.Send And Return    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}
        END
    ELSE
        IF    $log_name is None or $log_name == ''
            ${buffer}=    SSH_IT.Send And Return    ${cmd}    resp_timeout=${timeout}    prompt=${prompt}
        ELSE
            ${buffer}=    SSH_IT.Send And Return    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}    prompt=${prompt}
        END
    END
    RETURN    ${buffer}

IT COMMON - Get Dut Uptime Seconds
    [Documentation]    Return how many seconds the DUT has been up.

    ...              /proc/uptime holds the seconds since the boot of the
    ...              kernel, so this is the age of the running system. It is
    ...              the proof that a reboot really happened: after a reboot
    ...              the number is small again, a DUT that never went down
    ...              keeps counting.

    [Arguments]    ${timeout}=15
    ${buffer}=    IT COMMON - Run Dut Root Command And Return    cat /proc/uptime    ${timeout}
    ${seconds}=    Evaluate    float($buffer.split()[0])    modules=builtins
    RETURN    ${seconds}

IT COMMON - Get Count After Label
    [Documentation]    Read the number that follows a label in a clish output.

    ...              The clish prints a count on a line of its own, e.g.
    ...              " Total frequency exclusions         2", so the number is
    ...              the word behind the label.

    [Arguments]    ${text}    ${label}
    ${pattern}=    Evaluate    re.escape($label) + r'[ ]+([0-9]+)'    modules=re
    ${match}=    Evaluate    re.search($pattern, $text)    modules=re
    IF    $match is None
        Fail    Label "${label}" not found in output:\n${text}
    END
    ${count}=    Evaluate    int($match.group(1))    modules=re
    RETURN    ${count}

IT COMMON - Get Clish Field
    [Documentation]    Read exactly one labelled field from a clish configuration table.
    [Arguments]    ${text}    ${key}
    ${pattern}=    Evaluate    '^' + re.escape($key) + '[ ]{2,}([^ ]+)'    modules=re
    ${values}=    Evaluate    [m.group(1) for line in $text.splitlines() for m in [re.match($pattern, line.strip())] if m]    modules=re
    ${count}=    Get Length    ${values}
    Should Be Equal As Integers    ${count}    1    msg=Expected one field "${key}", found ${count}:\n${text}
    RETURN    ${values}[0]

IT COMMON - Clish Number Should Equal
    [Arguments]    ${text}    ${key}    ${expected}
    ${value}=    IT COMMON - Get Clish Field    ${text}    ${key}
    Should Be Equal As Numbers    ${value}    ${expected}    msg=Field "${key}" is "${value}", expected "${expected}".\nOutput:\n${text}

IT COMMON - Restore eCM Factory Offset
    [Arguments]    ${original}
    ${restore}=    IT COMMON - Run Dut Root Command And Return    echo ${original} > /mnt/sc_factory/ecm_rfb_offset
    ${out}=    IT COMMON - Run Dut Command And Return    cat /mnt/sc_factory/ecm_rfb_offset
    ${read}=    Evaluate    $out.strip()
    Should Be Equal    ${read}    ${original}    msg=eCM offset restoration failed: expected ${original}, read ${read}

IT COMMON - Read Journal Cursor
    [Documentation]    Capture a validated global journal cursor before a device operation.
    ${out}=    IT COMMON - Run Dut Root Command And Return    SYSTEMD_COLORS=0 journalctl --no-pager -n 1 --show-cursor -o cat | tail -1
    ${line}=    Evaluate    $out.strip()
    Should Start With    ${line}    -- cursor:     msg=Could not read the journal cursor: ${out}
    ${cursor}=    Evaluate    $line[len('-- cursor: '):]
    Should Match Regexp    ${cursor}    ^s=[0-9a-f]+;i=[0-9a-f]+;b=[0-9a-f]+;m=[0-9a-f]+;t=[0-9a-f]+;x=[0-9a-f]+$
    RETURN    ${cursor}

IT COMMON - Read Legacy Calibration Journal
    [Documentation]    Read exactly one legacy calibration record newer than the supplied cursor.
    [Arguments]    ${cursor}
    Should Match Regexp    ${cursor}    ^s=[0-9a-f]+;i=[0-9a-f]+;b=[0-9a-f]+;m=[0-9a-f]+;t=[0-9a-f]+;x=[0-9a-f]+$
    ${raw}=    IT COMMON - Run Dut Root Command And Return
    ...    SYSTEMD_COLORS=0 journalctl --no-pager -u sc_alignment --after-cursor '${cursor}' -o json --output-fields=MESSAGE    timeout=60
    TRY
        ${records}=    Evaluate    [json.loads(line) for line in $raw.splitlines() if line.strip()]    modules=json
    EXCEPT    *JSONDecodeError*    type=GLOB
        Fail    Cannot parse sc_alignment journal JSON:\n${raw}
    END
    ${matches}=    Evaluate    [record['MESSAGE'] for record in $records if isinstance(record.get('MESSAGE'), str) and 'ExecutePostUs1' in record['MESSAGE'] and 'isCmOperational=' in record['MESSAGE']]
    ${count}=    Get Length    ${matches}
    Should Be Equal As Integers    ${count}    1    msg=Expected one new legacy calibration journal record, found ${count}.
    RETURN    ${matches}[0]

IT COMMON - Get Number After Colon
    [Documentation]    Read the number that follows a label with a colon in a
    ...              command output.

    ...              Some outputs do not use the "key = value" form of the
    ...              clish, e.g. "South Port rlsp: 8.000000 dBmv", so the
    ...              number is read behind the colon instead.

    [Arguments]    ${text}    ${label}
    ${pattern}=    Evaluate    re.escape($label) + r'[ ]*:[ ]*([0-9.]+)'    modules=re
    ${match}=    Evaluate    re.search($pattern, $text)    modules=re
    IF    $match is None
        Fail    Label "${label}" not found in output:\n${text}
    END
    ${number}=    Evaluate    float($match.group(1))    modules=re
    RETURN    ${number}

IT COMMON - Get Text After Label
    [Documentation]    Read the text that follows a label in a command output.

    ...              Some outputs do not use the "key = value" form of the
    ...              clish, e.g. "Result: SUCCESS" or
    ...              " Calibrating                 false", so the text is read
    ...              behind the label. The colon is optional and the text
    ...              ends at the end of the line.

    [Arguments]    ${text}    ${label}
    ${pattern}=    Evaluate    re.escape($label) + r'[ ]*[:]?[ ]*(.+)'    modules=re
    ${match}=    Evaluate    re.search($pattern, $text)    modules=re
    IF    $match is None
        Fail    Label "${label}" not found in output:\n${text}
    END
    ${value}=    Evaluate    $match.group(1).strip()    modules=re
    RETURN    ${value}

IT COMMON - Progress Line Order
    [Documentation]    Check that the progress lines of a calibration output
    ...              show the stages in the expected order.

    ...              The calibration prints one "Progress: STAGE_XX" line per
    ...              stage, and the order of the lines is the order the
    ...              stages ran in.

    [Arguments]    ${text}    @{stages}
    ${positions}=    Evaluate    [$text.find('Progress: STAGE_' + s) for s in $stages]    modules=builtins
    FOR    ${position}    IN    @{positions}
        IF    ${position} < 0
            Fail    A stage of ${stages} is not in the output:\n${text}
        END
    END
    ${ordered}=    Evaluate    $positions == sorted($positions)    modules=builtins
    IF    not $ordered
        Fail    The stages did not run in the expected order, the positions are ${positions}.\n${text}
    END
    RETURN    ${positions}

IT COMMON - Check Calibration Result
    [Documentation]    Check the result line of a calibration command.

    ...              The calibration service ends its answer with either
    ...              "Result: SUCCESS" or with "Result: FAILURE" and the
    ...              stage it gave up on ("Alignment failed for stage: N").
    ...              The stage number of that message is the one of the
    ...              calibration service: US1=0, DS1=1, DS2=2 and DS3=3.

    ...              A stage that is not the first one of the manual chain
    ...              is given up on when the stage before it was not run in
    ...              the manual mode before, that is the sequential stage
    ...              dependency rule of the User Guide.

    [Arguments]    ${text}    ${stage}
    ${result}=    IT COMMON - Get Text After Label    ${text}    Result
    IF    "${result}" == "SUCCESS"
        RETURN    ${result}
    END
    ${number}=    IT COMMON - Get Number After Colon    ${text}    Alignment failed for stage
    ${ok}=    Evaluate    int($number) == int($stage)    modules=builtins
    IF    not $ok
        Fail    The calibration gave up on the stage ${number}, expected ${stage}:\n${text}
    END
    Fail    The calibration gave up on the stage ${number} (the stage before it was not run in the manual mode):\n${text}

IT COMMON - Get Dut Login Banner
    [Documentation]    Return what a new SSH session of the DUT prints before
    ...              its prompt.

    ...              A login banner shows up in the banner of a new session, so
    ...              this keyword opens a session of its own, reads it and
    ...              closes it again. The session of the suite is not touched.

    [Arguments]    ${timeout}=10
    ${banner}=    SSH_IT_BANNER.Connect And Return Banner    ${SSH_DUT_IT}    timeout=${timeout}
    RETURN    ${banner}

IT COMMON - Run Fdx Command And Return Buffer
    [Documentation]    Run a clish command and return the raw buffer, even when
    ...              the prompt did not come in time.

    ...              A command that opens a shell of its own, e.g. the Broadcom
    ...              HAL, changes the prompt and does not give it back until
    ...              the shell is left. When the DUT does not answer with the
    ...              prompt at all, the buffer is the only evidence of what it
    ...              did, so this keyword returns it in that case as well.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}    ${prompt}=${NONE}
    IF    $prompt is None
        ${buffer}=    SSH_IT.Send And Return Buffer    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}
    ELSE
        ${buffer}=    SSH_IT.Send And Return Buffer    ${cmd}    resp_timeout=${timeout}    log_name=${log_name}    prompt=${prompt}
    END
    RETURN    ${buffer}

IT COMMON - Strip Command Echo
    [Documentation]    Cut the echoed command and the trailing prompt out of a shell buffer.

    ...              The buffer looks like this:

    ...              | sc_cli get_pab_config
    ...              | PAB Configuration:
    ...              |   rx adc lna mode      : 2 (FREE_RUNNING)
    ...              | bash-3.2#

    ...              The first line is the echo of what was sent and the last line
    ...              is the prompt, so the payload is everything in between.

    [Arguments]    ${buffer}    ${cmd}=${EMPTY}
    ${lines}=    Split To Lines    ${buffer}
    # The echoed command is the first line, but the PTY may have wrapped it, so
    # the echo is matched on its first word rather than on the whole string.
    ${first_word}=    Evaluate    $cmd.split()[0] if $cmd else ""    modules=string
    IF    $lines and $first_word and $lines[0].startswith($first_word)
        ${lines}=    Evaluate    $lines[1:]
    END
    # The prompt is cut off the end of the last line and the line is kept,
    # because the shell does not put a newline between the output and the
    # prompt: the last brace of a JSON file and the prompt of the shell end up
    # in the same line, and cutting the line would take the brace with it.
    # A prompt is a run of non blank characters that ends in "#", ">" or "$"
    # ("bash-3.2#", "root@scamp:~#", "FDX-AMP>$"). The look ahead keeps a
    # brace of the payload from being taken with the prompt.
    ${last}=    Evaluate    $lines[-1] if $lines else ""    modules=builtins
    ${stripped}=    Evaluate
    ...    re.sub(r'(?![^ ]*})[^ ]*[#$>]+[ ]*$', '', $last)
    ...    modules=re
    ${lines}=    Evaluate    $lines[:-1] + [$stripped]    modules=builtins
    ${text}=    Catenate    SEPARATOR=\n    @{lines}
    ${text}=    Evaluate    $text.rstrip()    modules=builtins
    RETURN    ${text}

IT COMMON - Find Key Value
    [Documentation]    Read one labelled field out of a command output, or return None.

    ...              The regexp is built here rather than in the suites, so the
    ...              escaping is under control: the key is escaped literally and
    ...              the blanks are matched with a character class instead of
    ...              "\s", which Robot Framework would eat.

    [Arguments]    ${text}    ${key}
    ${match}=    Evaluate
    ...    re.search('(?m)^[ ]*' + re.escape($key) + '[ ]*[:=][ ]*(.*)$', $text)
    ...    modules=re
    IF    $match is None
        RETURN    ${None}
    END
    ${value}=    Evaluate    $match.group(1).strip()    modules=re
    RETURN    ${value}

IT COMMON - Get Key Value
    [Documentation]    Read one "key : value" or "key = value" line out of a command output.

    ...              The CLI families disagree on the separator: sc_cli get_pab_config
    ...              prints "rx adc lna mode      : 2 (FREE_RUNNING)" while
    ...              sc_cli get_asc_config prints "operationMode = FreeRun". This
    ...              keyword accepts both.

    ...              The key is matched literally, so "target tcp" does not match
    ...              "target tcp power" and "eCM online" does not match "eCM".

    [Arguments]    ${text}    ${key}
    ${value}=    IT COMMON - Find Key Value    ${text}    ${key}
    IF    $value is None
        Fail    Key "${key}" not found in output:\n${text}
    END
    RETURN    ${value}

IT COMMON - Get Cli Field
    [Documentation]    Read one field out of an sc_cli output by its label.

    ...              A thin wrapper over IT COMMON - Get Key Value that keeps the
    ...              call sites short, e.g. "rx adc lna mode" carries spaces so it
    ...              has to be quoted anyway.

    [Arguments]    ${text}    ${key}
    ${value}=    IT COMMON - Get Key Value    ${text}    ${key}
    RETURN    ${value}

IT COMMON - Get Cli Field Or Default
    [Documentation]    Read one field out of a command output, or a fallback value.

    ...              Used where the field is not printed at all in some states, so
    ...              a missing field is not a test failure but an expected value.

    [Arguments]    ${text}    ${key}    ${default}=${EMPTY}
    ${value}=    IT COMMON - Find Key Value    ${text}    ${key}
    IF    $value is None
        RETURN    ${default}
    END
    RETURN    ${value}

IT COMMON - Get Inline Values
    [Documentation]    The value of a label on every line that carries it.

    ...              Used where a command prints a table and every line carries
    ...              the same label, e.g. "config = 21.00 dB" in the
    ...              attenuation table of the RF board.

    [Arguments]    ${text}    ${label}
    ${pattern}=    Evaluate    r'%s[ ]*=[ ]*([^,]+)' % re.escape($label)    modules=re
    ${values}=    Evaluate    [m.group(1).strip().rstrip(']').strip() for m in re.finditer($pattern, $text)]    modules=re
    RETURN    ${values}

IT COMMON - Get Inline Field
    [Documentation]    Read a value out of a line that carries more than one label.

    ...              Some commands print everything on one line, e.g.
    ...              "state=2 name=ON_HOLD" or
    ...              "palGetNorthAfeInputTargetTcp success (value=33.099998 dBmV)".
    ...              The label of such a line is not at the start of it, so the
    ...              line anchored read of IT COMMON - Get Cli Field does not
    ...              find it.

    ...              The value ends at the first blank, and the lines are joined
    ...              with a blank first, so that a value on the last line of an
    ...              output does not run into the line behind it.

    [Arguments]    ${text}    ${key}
    ${flat}=    Evaluate    $text.replace(chr(10), ' ')    modules=builtins
    ${match}=    Evaluate
    ...    re.search(re.escape($key) + '[ ]*=[ ]*([^ ]+)', $flat)
    ...    modules=re
    IF    $match is None
        Fail    Key "${key}" not found in output:\n${text}
    END
    ${value}=    Evaluate    $match.group(1)    modules=re
    RETURN    ${value}

IT COMMON - Cli Inline Number Should Equal
    [Documentation]    Read an inline field out of a command output and compare it as a number.

    [Arguments]    ${text}    ${key}    ${expected}
    ${value}=    IT COMMON - Get Inline Field    ${text}    ${key}
    ${ok}=    Evaluate    abs(float($value) - float($expected)) < 0.001    modules=builtins
    IF    not $ok
        Fail    Field "${key}" is "${value}", expected "${expected}".\nOutput:\n${text}
    END
    RETURN    ${value}

IT COMMON - Read Live Nonvol Number
    [Documentation]    Read a nonvol number at full double precision from the running service.

    [Arguments]    ${path}
    Should Match Regexp    ${path}    ^/[a-z_0-9/]+$
    ${out}=    IT COMMON - Run Dut Root Command And Return
    ...    python -c 'import ctypes; l=ctypes.CDLL("/usr/lib/libsc_cfg.so.1"); v=ctypes.c_double(); r=l.libsc_nonvol_get_number("${path}",ctypes.byref(v)); assert r == 0, "nonvol get failed: %d" % r; print("value=%.17g" % v.value)'
    ${value}=    IT COMMON - Get Inline Field    ${out}    value
    ${valid}=    Evaluate    math.isfinite(float($value))    modules=math
    Should Be True    ${valid}    Nonvol value is not finite: ${value}
    RETURN    ${value}

IT COMMON - Cli Field Should Equal
    [Documentation]    Read a field out of a command output and compare it.

    ...              On a mismatch the whole output is printed, otherwise a
    ...              failing comparison only says "1 != 2" and the reader has to
    ...              go and look for the command output.

    [Arguments]    ${text}    ${key}    ${expected}
    ${value}=    IT COMMON - Get Cli Field    ${text}    ${key}
    IF    "${value}" != "${expected}"
        Fail    Field "${key}" is "${value}", expected "${expected}".\nOutput:\n${text}
    END
    RETURN    ${value}

IT COMMON - Cli Number Should Equal
    [Documentation]    Read a field out of a command output and compare it as a number.

    ...              The CLI prints the numbers with a unit ("36.00 dBmV") and
    ...              with a fixed number of decimals, so the value is compared
    ...              numerically instead of as a string.

    [Arguments]    ${text}    ${key}    ${expected}
    ${value}=    IT COMMON - Get Cli Field    ${text}    ${key}
    ${number}=    Evaluate    float($value.split()[0])    modules=builtins
    ${ok}=    Evaluate    abs($number - float($expected)) < 0.001    modules=builtins
    IF    not $ok
        Fail    Field "${key}" is "${value}", expected "${expected}".\nOutput:\n${text}
    END
    RETURN    ${number}

# ---------------------------------------------------------------------------
# Assertions on the output of a command
# ---------------------------------------------------------------------------
IT COMMON - Dut Command Should Contain
    [Documentation]    Run a command on the DUT and check that the output contains a text.

    [Arguments]    ${cmd}    ${expected}    ${timeout}=15    ${log_name}=${sc_log}
    ${out}=    IT COMMON - Run Dut Command And Return    ${cmd}    ${timeout}    ${log_name}
    IF    "${expected}" not in $out
        Fail    Output of "${cmd}" does not contain "${expected}".\nOutput:\n${out}
    END
    RETURN    ${out}

IT COMMON - Dut Command Should Not Contain
    [Documentation]    Run a command on the DUT and check that the output does not contain a text.

    [Arguments]    ${cmd}    ${unexpected}    ${timeout}=15    ${log_name}=${sc_log}
    ${out}=    IT COMMON - Run Dut Command And Return    ${cmd}    ${timeout}    ${log_name}
    IF    "${unexpected}" in $out
        Fail    Output of "${cmd}" contains "${unexpected}".\nOutput:\n${out}
    END
    RETURN    ${out}

IT COMMON - Dut Command Should Succeed
    [Documentation]    Run a command on the DUT and check that it reported success.

    ...              The CLI families all print their own wording: sc_cli uses
    ...              "Success: ...", sc_rfboard_cli uses "<command>...success" and
    ...              the gRPC answers carry a "success" object. This keyword
    ...              accepts the sc_cli and sc_rfboard_cli wordings.

    [Arguments]    ${cmd}    ${timeout}=15    ${log_name}=${sc_log}
    ${out}=    IT COMMON - Run Dut Command And Return    ${cmd}    ${timeout}    ${log_name}
    IF    "Success" not in $out and "success" not in $out
        Fail    Command "${cmd}" did not report success.\nOutput:\n${out}
    END
    RETURN    ${out}

IT COMMON - Value Should Be One Of
    [Documentation]    Check that a value is one of a list of allowed values.

    ...              Used for the enumerations of the gNMI and gRPC answers,
    ...              e.g. the alignment status of a stage.

    [Arguments]    ${value}    ${allowed}
    IF    "${value}" not in $allowed
        Fail    Value "${value}" is not one of ${allowed}
    END
    RETURN    ${value}

# ---------------------------------------------------------------------------
# The lifecycle of the DUT
# ---------------------------------------------------------------------------
IT COMMON - Wait For Dut To Come Back
    [Documentation]    Wait until the DUT is back after a reboot.

    ...              A reboot takes the SSH session down. The next keyword
    ...              that talks to the DUT rebuilds the session, but the
    ...              connect gives up after the connect timeout (10 s), which
    ...              is much shorter than the boot of the DUT. This waits.

    ...              The other two sessions died with it as well, and their
    ...              transports do not notice it right away: the first command
    ...              on them would run on a dead channel and fail with an exit
    ...              status of -1. They are rebuilt by hand.

    ...              The AMP services come up after the SSH service, so the
    ...              wait goes on until the gNMI server of the DUT answers.
    ...              That is the same request the suites use, so the wait
    ...              proves the gNMI path works.

    ...              The boot of the bench unit takes about 90 s, but it was
    ...              measured at 10 minutes once, when the DUT came back with a
    ...              new configuration, so the timeout is generous.

    [Arguments]    ${timeout}=900    ${interval}=10
    SSH_IT.Wait For Connection    ${timeout}    ${interval}
    SSH_IT_ROOT.Wait For Connection    ${timeout}    ${interval}
    GNMI_IT.Wait For Connection    ${timeout}    ${interval}
    ${out}=    IT COMMON - Run Dut Root Command And Return
    ...    until gnmic -a 127.0.0.1:9339 --insecure get --path configuration-status >/dev/null 2>&1; do sleep ${interval}; done; echo gNMI_UP
    ...    timeout=300
    Should Contain    ${out}    gNMI_UP
    ...    msg=The gNMI server of the DUT did not come up within the timeout. The answer was:\n${out}
    ${uptime}=    IT COMMON - Run Dut Command And Return    uptime
    Log    The DUT is back, uptime: ${uptime}

# ---------------------------------------------------------------------------
# The firmware of the campaign
# ---------------------------------------------------------------------------
IT COMMON - Firmware Image Should Be On Server
    [Documentation]    Check that a firmware image is on the firmware server.

    ...              The DUT downloads the image itself over HTTP, so an image
    ...              that was never uploaded makes the upgrade fail with a
    ...              download error. This says it before the upgrade starts.

    ...              The request goes out from the DUT, not from the machine
    ...              that runs the tests, because the DUT is the one that has to
    ...              reach the server: it reaches it over the management port.

    ...              It is a HEAD request on purpose. A GET would pull the
    ...              whole image (288 MB) down the DUT to answer a question.

    ...              There is more than one image server on the bench and they
    ...              do not carry the same images, so the server can be given
    ...              here as well. See images/README.md.

    [Arguments]    ${image}    ${server}=${FW_SERVER}    ${timeout}=25
    ${url}=    Catenate    SEPARATOR=    http://${server}/    ${image}
    ${head}=    IT COMMON - Run Dut Root Command And Return
    ...    curl -sI --max-time ${timeout} ${url} | head -n 2
    Log    ${head}
    Should Contain    ${head}    200 OK
    ...    msg=The firmware image ${image} is not on the firmware server ${server}. The answer of the server was:\n${head}
    RETURN    ${head}

# ---------------------------------------------------------------------------
# Waiting for a state change on the DUT
# ---------------------------------------------------------------------------
IT COMMON - Wait For Dut Json File
    [Documentation]    Read a JSON file of the DUT and parse it.

    ...              The services of the DUT write their files while they run,
    ...              so a read can catch a file that is half written. The file
    ...              is read again until it parses, at most ${timeout} seconds.

    [Arguments]    ${path}    ${timeout}=60    ${poll}=2
    ${end}=    Evaluate    time.time() + float($timeout)    modules=time
    ${now}=    Evaluate    time.time()    modules=time
    ${parsed}=    Evaluate    None    modules=builtins
    WHILE    $now < $end
        ${text}=    IT COMMON - Run Dut Root Command And Return Buffer    cat ${path}
        TRY
            ${parsed}=    Evaluate    json.loads($text)    modules=json
        EXCEPT
            Log    ${path} does not hold valid JSON yet
        END
        IF    $parsed is not None
            RETURN    ${parsed}
        END
        Sleep    ${poll}
        ${now}=    Evaluate    time.time()    modules=time
    END
    Fail    The file ${path} did not hold valid JSON within ${timeout}s

IT COMMON - Wait For File On Dut
    [Documentation]    Wait until a file exists on the DUT and return its size in bytes.

    [Arguments]    ${path}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    WHILE    $end > time.time()
        ${out}=    IT COMMON - Run Dut Root Command And Return Buffer    ls -l ${path}
        ${match}=    Evaluate
        ...    re.search(r'(?m)^-[^ ]+[ ]+[^ ]+[ ]+[^ ]+[ ]+[^ ]+[ ]+([0-9]+)', $out)
        ...    modules=re
        IF    $match is not None
            RETURN    ${match.group(1)}
        END
        Sleep    ${interval}
    END
    Fail    File "${path}" did not appear on the DUT within ${timeout}s

IT COMMON - Wait For Dut Command Contains
    [Documentation]    Poll a command on the DUT until its output contains a text.

    ...              The regex free counterpart of IT COMMON - Wait For Dut Command
    ...              Match, and the one the suites should use.

    ...              The answer of the last poll is part of the failure message,
    ...              so a reader sees what the DUT actually said and not only
    ...              that the expected text was missing. That matters for the
    ...              cases that wait for a state the bench may not be in, e.g.
    ...              "eCM status = Operational" while the eCM is ranging.

    [Arguments]    ${cmd}    ${text}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    ${last}=    Set Variable    ${EMPTY}
    WHILE    $end > time.time()
        ${out}=    IT COMMON - Run Dut Root Command And Return Buffer    ${cmd}
        ${last}=    Set Variable    ${out}
        IF    "${text}" in $out
            RETURN    ${out}
        END
        Sleep    ${interval}
    END
    Fail    Command "${cmd}" did not contain "${text}" within ${timeout}s. The last answer was:\n${last}

IT COMMON - Wait For Dut Cli Field Different
    [Documentation]    Poll a command on the DUT until one labelled field has a value that is not the one given.

    ...              The counterpart of IT COMMON - Wait For Dut Cli Field, for the
    ...              cases where the state that tells the test that something
    ...              happened is the absence of a value: e.g. the stage of the
    ...              PAB is not IDLE any more because a round is running.

    [Arguments]    ${cmd}    ${key}    ${unexpected}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    WHILE    $end > time.time()
        ${out}=    IT COMMON - Run Dut Root Command And Return Buffer    ${cmd}
        ${value}=    IT COMMON - Find Key Value    ${out}    ${key}
        IF    $value is not None and $value != $unexpected
            RETURN    ${out}
        END
        Sleep    ${interval}
    END
    Fail    Command "${cmd}" did not leave "${key}" = "${unexpected}" within ${timeout}s

IT COMMON - Run Dut Command Until Not Refused
    [Documentation]    Run a command on the DUT until it is not refused.

    ...              Some commands of the DUT ask the MSC for the amplifier
    ...              before they do their work, e.g. "sc_cli calib_us_legacy"
    ...              asks for the ALN control. The MSC gives the amplifier to
    ...              the PAB service now and then and refuses the request
    ...              while the PAB has it ("Failed to request ALN control from
    ...              MSC, 7"). The refusal is not a fault of the DUT, so the
    ...              command is run again until the amplifier is free.

    [Arguments]    ${cmd}    ${refusal}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}    ${cmd_timeout}=60
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    WHILE    $end > time.time()
        ${out}=    IT COMMON - Run Dut Root Command And Return Buffer    ${cmd}    timeout=${cmd_timeout}
        IF    "${refusal}" not in $out
            RETURN    ${out}
        END
        Log    The command was refused, it is run again: ${out}
        Sleep    ${interval}
    END
    Fail    Command "${cmd}" was still refused with "${refusal}" after ${timeout}s

IT COMMON - Wait For Dut Cli Field
    [Documentation]    Poll a command on the DUT until one labelled field has a value.

    [Arguments]    ${cmd}    ${key}    ${expected}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    WHILE    $end > time.time()
        ${out}=    IT COMMON - Run Dut Root Command And Return Buffer    ${cmd}
        ${value}=    IT COMMON - Find Key Value    ${out}    ${key}
        IF    $value is not None and "${value}" == "${expected}"
            RETURN    ${out}
        END
        Sleep    ${interval}
    END
    Fail    Command "${cmd}" did not reach "${key}" = "${expected}" within ${timeout}s

IT COMMON - Wait For Dut Cli Fields
    [Documentation]    Poll a command on the DUT until every labelled field has its value.

    ...              ${fields} is a list of "label=value" strings, e.g.

    ...              | ${fields}=    Create List    Completed=Yes    Current Stage=IDLE
    ...              | ${out}=    IT COMMON - Wait For Dut Cli Fields    sc_cli get_pab_status    ${fields}

    [Arguments]    ${cmd}    ${fields}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    WHILE    $end > time.time()
        ${out}=    IT COMMON - Run Dut Root Command And Return Buffer    ${cmd}
        ${all_match}=    Evaluate    True    modules=builtins
        FOR    ${field}    IN    @{fields}
            ${parts}=    Split String    ${field}    separator==    max_split=1
            ${label}=    Get From List    ${parts}    0
            ${wanted}=    Get From List    ${parts}    1
            ${value}=    IT COMMON - Find Key Value    ${out}    ${label}
            IF    $value is None or $value != $wanted
                ${all_match}=    Evaluate    False    modules=builtins
                BREAK
            END
        END
        IF    $all_match
            RETURN    ${out}
        END
        Sleep    ${interval}
    END
    Fail    Command "${cmd}" did not reach ${fields} within ${timeout}s

IT COMMON - Wait For Dut Command Match
    [Documentation]    Poll a command on the DUT until its output matches a regexp.

    ...              Used by the cases that wait for a state change to land, e.g.
    ...              the PAB status turning into DONE. Prefer
    ...              IT COMMON - Wait For Dut Command Contains and
    ...              IT COMMON - Wait For Dut Cli Field: a regexp written into a
    ...              suite loses every backslash that Robot Framework does not
    ...              know, so "\s" arrives as "s".

    [Arguments]    ${cmd}    ${pattern}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    WHILE    $end > time.time()
        ${out}=    IT COMMON - Run Dut Root Command And Return Buffer    ${cmd}
        ${match}=    Evaluate    re.search($pattern, $out)    modules=re
        IF    $match is not None
            RETURN    ${out}
        END
        Sleep    ${interval}
    END
    Fail    Command "${cmd}" did not produce a match for "${pattern}" within ${timeout}s

IT COMMON - Wait For Dut Exec Contains
    [Documentation]    Poll a command on the DUT until its output contains a text.

    ...              The same as IT COMMON - Wait For Dut Command Contains but the
    ...              command runs through the non interactive exec channel, which
    ...              is what gnmic and grpcurl need.

    [Arguments]    ${cmd}    ${text}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    WHILE    $end > time.time()
        ${out}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}
        IF    "${text}" in $out
            RETURN    ${out}
        END
        Sleep    ${interval}
    END
    Fail    Command "${cmd}" did not contain "${text}" within ${timeout}s

# ---------------------------------------------------------------------------
# gNMI
# ---------------------------------------------------------------------------
IT COMMON - Gnmi Get And Return
    [Documentation]    Read one or more gNMI paths from the DUT and return the parsed response.

    ...              gnmic runs on the DUT (see IT COMMON - Grpcurl And Return Json
    ...              for why), against the loopback gNMI port.

    [Arguments]    ${paths}    ${timeout}=15    ${log_name}=${sc_log}
    ${result}=    GNMI_IT.Get And Return    ${paths}    resp_timeout=${timeout}    log_name=${log_name}
    RETURN    ${result}

IT COMMON - Gnmi Get Raw
    [Documentation]    Read gNMI paths from the DUT and return the raw answer.

    ...              Used where the answer is not a JSON object, e.g. the
    ...              capabilities of the server or the whole data tree.

    [Arguments]    ${paths}    ${timeout}=30    ${log_name}=${sc_log}
    ${cmd}=    Catenate
    ...    SEPARATOR=${SPACE}
    ...    gnmic -u gnmi -p sercommgnmi -a 127.0.0.1:9339 --insecure get --path '${paths}'
    ${raw}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    ${timeout}    ${log_name}
    RETURN    ${raw}

IT COMMON - Gnmi Set And Return
    [Documentation]    Send a gNMI SET request to the DUT and return the raw answer.

    ...              ${updates} is a list of the --update arguments, e.g.
    ...              "/amp-identification/device-location/description:::string:::Lab"

    [Arguments]    ${updates}    ${timeout}=30    ${log_name}=${sc_log}
    ${cmd}=    Catenate
    ...    SEPARATOR=${SPACE}
    ...    gnmic -u gnmi -p sercommgnmi -a 127.0.0.1:9339 --insecure set --update
    FOR    ${update}    IN    @{updates}
        ${cmd}=    Catenate    ${cmd}    ${update}
    END
    ${raw}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    ${timeout}    ${log_name}
    RETURN    ${raw}

IT COMMON - Gnmi Capabilities And Return
    [Documentation]    Read the capabilities of the gNMI server of the DUT.

    [Arguments]    ${timeout}=30    ${log_name}=${sc_log}
    ${cmd}=    Catenate
    ...    SEPARATOR=${SPACE}
    ...    gnmic -u gnmi -p sercommgnmi -a 127.0.0.1:9339 --insecure capabilities
    ${raw}=    IT COMMON - Run Dut Exec Command And Return    ${cmd}    ${timeout}    ${log_name}
    RETURN    ${raw}

IT COMMON - Gnmi Get Updates
    [Documentation]    Return the update list of a gnmic answer.

    ...              gnmic answers with a JSON array that holds one object per
    ...              target, so the updates live under the first element.

    ...              A request the DUT refuses is answered with text and not
    ...              with JSON, so the answer is checked before it is read.

    [Arguments]    ${response}
    ${updates}=    GnmiPath.Updates Of    ${response}
    RETURN    ${updates}

IT COMMON - Gnmi Get Leaf Value
    [Documentation]    Read one leaf out of a gNMI response.

    ...              The gnmic answer nests the values three levels deep, under
    ...              updates -> values -> <path>, so every caller would otherwise
    ...              repeat the same three index operations.

    [Arguments]    ${response}    ${path}
    ${value}=    GnmiPath.Resolve    ${response}    ${path}
    IF    $value is None
        ${text}=    Evaluate    str($response)[:400]    modules=builtins
        Fail    Path "${path}" not found in the gNMI response: ${text}
    END
    RETURN    ${value}

IT COMMON - Gnmi Leaf Names
    [Documentation]    Return the leaf names of one gNMI path.

    [Arguments]    ${response}    ${path}
    ${value}=    IT COMMON - Gnmi Get Leaf Value    ${response}    ${path}
    ${names}=    Evaluate    list($value.keys())    modules=builtins
    RETURN    ${names}

IT COMMON - Gnmi Get All Values
    [Documentation]    Return the values of every update of a gNMI answer.

    ...              A GET with a wildcard path answers with one update per
    ...              matched instance, and the values of such an update are
    ...              held under the path without its key selectors, so the
    ...              values have to be collected instead of looked up by the
    ...              path of the request.

    [Arguments]    ${response}
    ${values}=    GnmiPath.All Values    ${response}
    RETURN    ${values}

IT COMMON - Gnmi Get Leaf Value Or Default
    [Documentation]    Read one leaf out of a gNMI response, or a fallback value.

    ...              The answer of the DUT can lag the request: right after a
    ...              SET the answer of a GET can still carry the leaf of the
    ...              state before the request. A caller that polls for a
    ...              change uses this, so a missing leaf is not a failure but
    ...              "not yet".

    [Arguments]    ${response}    ${path}    ${default}=${EMPTY}
    ${value}=    GnmiPath.Resolve    ${response}    ${path}
    IF    $value is None
        RETURN    ${default}
    END
    RETURN    ${value}

IT COMMON - Gnmi Instances With
    [Documentation]    The instances of a wildcard answer whose leaf holds a value.

    ...              Used to ask whether the DUT is busy, e.g. whether any
    ...              alignment stage still reports ALIGN_STATUS_IN_PROGRESS.

    [Arguments]    ${response}    ${leaf}    ${value}
    ${instances}=    GnmiPath.Instances With    ${response}    ${leaf}    ${value}
    RETURN    ${instances}

IT COMMON - Wait For Gnmi Leaf Value
    [Documentation]    Wait until the leaf of a gNMI path holds a wanted value.

    ...              The answer of the GET is polled every ${poll} seconds
    ...              until the leaf holds one of ${accepted}, at most
    ...              ${timeout} seconds.

    [Arguments]    ${path}    ${accepted}    ${timeout}=300    ${poll}=5
    ${end}=    Evaluate    time.time() + float($timeout)    modules=time
    ${now}=    Evaluate    time.time()    modules=time
    VAR    ${value}    ${NONE}
    WHILE    $now < $end
        ${response}=    IT COMMON - Gnmi Get And Return    ${path}
        ${value}=    IT COMMON - Gnmi Get Leaf Value Or Default    ${response}    ${path}
        IF    $value in $accepted
            RETURN    ${value}
        END
        Sleep    ${poll}
        ${now}=    Evaluate    time.time()    modules=time
    END
    Fail    The leaf "${path}" did not reach ${accepted} within ${timeout}s, it reads "${value}"

IT COMMON - Wait For Gnmi Leaf Value Changed
    [Documentation]    Wait until the leaf of a gNMI path holds a new value.

    ...              Used to wait until the DUT has reacted to a request: a
    ...              leaf that carries a timestamp changes every time the DUT
    ...              answers differently, so it tells a fresh answer from the
    ...              one that was already there before the request.

    [Arguments]    ${path}    ${previous}    ${timeout}=120    ${poll}=2
    ${end}=    Evaluate    time.time() + float($timeout)    modules=time
    ${now}=    Evaluate    time.time()    modules=time
    VAR    ${value}    ${NONE}
    WHILE    $now < $end
        ${response}=    IT COMMON - Gnmi Get And Return    ${path}
        ${value}=    IT COMMON - Gnmi Get Leaf Value Or Default    ${response}    ${path}
        IF    $value != $previous
            RETURN    ${value}
        END
        Sleep    ${poll}
        ${now}=    Evaluate    time.time()    modules=time
    END
    Fail    The leaf "${path}" did not change within ${timeout}s, it still reads "${value}"

IT COMMON - Wait For No Gnmi Instance With
    [Documentation]    Wait until no instance of a wildcard path holds a value.

    ...              The answer of the GET is polled every ${poll} seconds
    ...              until no instance holds ${value} in its ${leaf}, at most
    ...              ${timeout} seconds. The DUT refuses a request while it
    ...              is busy, so a suite has to wait for the DUT to be free
    ...              before it sends one.

    [Arguments]    ${path}    ${leaf}    ${value}    ${timeout}=300    ${poll}=5
    ${end}=    Evaluate    time.time() + float($timeout)    modules=time
    ${now}=    Evaluate    time.time()    modules=time
    VAR    ${busy}    ${NONE}
    WHILE    $now < $end
        ${response}=    IT COMMON - Gnmi Get And Return    ${path}
        ${busy}=    IT COMMON - Gnmi Instances With    ${response}    ${leaf}    ${value}
        IF    $busy == []
            RETURN    ${busy}
        END
        Sleep    ${poll}
        ${now}=    Evaluate    time.time()    modules=time
    END
    Fail    The path "${path}" still holds ${value} in ${leaf} after ${timeout}s: ${busy}

IT COMMON - Gnmi Leaf Names Of
    [Documentation]    Return the leaf names of a value that is already a dict.

    [Arguments]    ${value}
    ${names}=    Evaluate    list($value.keys())    modules=builtins
    RETURN    ${names}

IT COMMON - Get Dict Field
    [Documentation]    Read one field out of a dictionary.

    ...              Used for the nested answers of gNMI and gRPC, e.g. the
    ...              stage objects of the PAB result container.

    [Arguments]    ${data}    ${field}
    IF    $field not in $data
        Fail    Field "${field}" not found in: ${data}
    END
    RETURN    ${data}[${field}]

IT COMMON - Gnmi Stage Leaves Should Exist
    [Documentation]    Check that a gNMI container holds a stage and that the stage holds its leaves.

    ...              The PAB result container holds the seven stages, and every
    ...              stage holds the leaves of that stage.

    ...              ${leaves} is the list of the wanted leaf names as a JSON
    ...              array, e.g. ["status", "message"]. The dictionary syntax of
    ...              Robot Framework carries strings only, so a list of leaves
    ...              travels as JSON.

    [Arguments]    ${container}    ${stage}    ${leaves}
    ${wanted}=    Evaluate    json.loads($leaves)    modules=json
    ${stage_value}=    IT COMMON - Get Dict Field    ${container}    ${stage}
    ${names}=    IT COMMON - Gnmi Leaf Names Of    ${stage_value}
    IT COMMON - Gnmi Leaves Should Exist    ${names}    ${wanted}
    RETURN    ${names}

IT COMMON - Gnmi Leaf Should Exist
    [Documentation]    Check that a leaf is present in the value of a gNMI path.

    ...              The IT template asks for "every leaf defined for the stage is
    ...              present", so the check is on the name, not on the value.

    [Arguments]    ${value}    ${leaf}
    IF    $leaf not in $value
        Fail    Leaf "${leaf}" is missing. Present leaves: ${value}
    END
    RETURN    ${leaf}

IT COMMON - Gnmi Leaves Should Exist
    [Documentation]    Check that every leaf of a list is present in a gNMI value.

    [Arguments]    ${value}    ${leaves}
    FOR    ${leaf}    IN    @{leaves}
        IT COMMON - Gnmi Leaf Should Exist    ${value}    ${leaf}
    END
    RETURN    ${leaves}

# ---------------------------------------------------------------------------
# gRPC
# ---------------------------------------------------------------------------
IT COMMON - Grpcurl And Return Raw
    [Documentation]    Call a gRPC method on the DUT and return the answer as it is.

    ...              grpcurl runs on the DUT through the same SSH session that
    ...              ViperGnmi uses, because that library opens a non interactive
    ...              exec channel: whatever the command is, it lands on the SSH
    ...              host, and the SSH host here is the DUT.

    [Arguments]    ${proto}    ${method}    ${data}=${EMPTY}    ${timeout}=15
    ${cmd}=    Catenate
    ...    SEPARATOR=${SPACE}
    ...    grpcurl -plaintext
    ...    -import-path ${GRPC_PROTO_PATH.path}
    ...    -proto ${proto}
    IF    $data == ""
        ${cmd}=    Catenate    ${cmd}    -d '{}'    ${GRPC_TARGET}    ${method}
    ELSE
        ${cmd}=    Catenate    ${cmd}    -d '${data}'    ${GRPC_TARGET}    ${method}
    END
    # The payload of a gRPC call is a JSON with double quotes, and clish
    # wraps the command of the exec channel in "sh -c \"...\"", which cuts
    # the payload apart. The call goes over the ROOT session of the DUT.
    ${raw}=    IT COMMON - Run Dut Root Command And Return    ${cmd}    ${timeout}
    RETURN    ${raw}

IT COMMON - Grpcurl And Return Json
    [Documentation]    Call a gRPC method on the DUT and return the parsed response.

    ...              An answer that holds one JSON document gives that document,
    ...              an answer of a streaming call holds one document per
    ...              message and gives the list of them.

    [Arguments]    ${proto}    ${method}    ${data}=${EMPTY}    ${timeout}=15
    ${raw}=    IT COMMON - Grpcurl And Return Raw    ${proto}    ${method}    ${data}    ${timeout}
    ${documents}=    GrpcJson.Parse Documents    ${raw}
    IF    not $documents
        Fail    The gRPC call ${method} did not answer with JSON: ${raw}
    END
    IF    len($documents) == 1
        RETURN    ${documents[0]}
    END
    RETURN    ${documents}

IT COMMON - Grpcurl And Return Json List
    [Documentation]    Call a gRPC method on the DUT and return every JSON
    ...              document of the answer.

    ...              A streaming call answers with one document per message,
    ...              e.g. the progress of the calibration stages of
    ...              StartCalibration and the failure at the end of it.

    [Arguments]    ${proto}    ${method}    ${data}=${EMPTY}    ${timeout}=15
    ${raw}=    IT COMMON - Grpcurl And Return Raw    ${proto}    ${method}    ${data}    ${timeout}
    ${documents}=    GrpcJson.Parse Documents    ${raw}
    IF    not $documents
        Fail    The gRPC call ${method} did not answer with JSON: ${raw}
    END
    RETURN    ${documents}

IT COMMON - Grpc Should Succeed
    [Documentation]    Check that a gRPC answer carries success.status = SUCCESS.

    [Arguments]    ${response}
    ${success}=    IT COMMON - Grpc Get Field    ${response}    success
    ${status}=    IT COMMON - Grpc Get Field    ${success}    status
    IF    "${status}" != "SUCCESS"
        Fail    gRPC call did not succeed: ${response}
    END
    RETURN    ${response}

IT COMMON - Grpc Get Field
    [Documentation]    Read one field out of a parsed gRPC response.

    [Arguments]    ${response}    ${field}
    IF    $field not in $response
        Fail    Field "${field}" not found in the gRPC response: ${response}
    END
    RETURN    ${response}[${field}]

IT COMMON - Grpc Get Nested
    [Documentation]    Read a field out of a nested gRPC response object.

    ...              ${path} is a list of keys, e.g. ["pabConfig", "pabTargetTcp"].

    [Arguments]    ${response}    ${path}
    ${value}=    Evaluate
    ...    __import__('functools').reduce(lambda o, k: o[k], $path, $response)
    ...    modules=builtins
    RETURN    ${value}

IT COMMON - Grpc Field Should Exist
    [Documentation]    Check that a field is present in a gRPC answer object.

    [Arguments]    ${response}    ${field}
    IF    $field not in $response
        Fail    Field "${field}" not found in the gRPC response: ${response}
    END
    RETURN    ${response}[${field}]

IT COMMON - Grpc Should Not Have Field
    [Documentation]    Check that a field is not present in a gRPC answer object.

    ...              A failed call carries a "failure" object instead of a
    ...              "success" one, so the absence of the failure object is
    ...              what tells the two apart.

    [Arguments]    ${response}    ${field}
    IF    $field in $response
        Fail    Field "${field}" is present in the gRPC response: ${response}
    END
    RETURN    ${response}

IT COMMON - Grpc Number Should Equal
    [Documentation]    Read a field out of a gRPC answer and compare it as a number.

    ...              gRPC answers carry the numbers as JSON numbers, so the
    ...              comparison has to be numeric: "36" and "36.0" are the same
    ...              value but not the same string.

    [Arguments]    ${response}    ${path}    ${expected}
    ${value}=    IT COMMON - Grpc Get Nested    ${response}    ${path}
    ${ok}=    Evaluate    abs(float($value) - float($expected)) < 0.001    modules=builtins
    IF    not $ok
        Fail    Field ${path} is "${value}", expected "${expected}".\nResponse: ${response}
    END
    RETURN    ${value}

IT COMMON - Grpc Enum Should Match Cli
    [Documentation]    Compare an enum of a gRPC answer with the text of the CLI.

    ...              The gRPC answer carries the full name of the enum, e.g.
    ...              "ALIGN_PAB_STAGE_2", while the CLI prints the short name,
    ...              e.g. "STAGE2". The underscores are taken out of both
    ...              before they are compared: the CLI has none in the stage
    ...              names, but the gRPC answer has one between the word and
    ...              the number. Without that the two answers only match while
    ...              the PAB is idle, and a PAB that is in the middle of a round
    ...              would report a mismatch that is not there.

    [Arguments]    ${grpc_value}    ${cli_value}
    ${grpc_short}=    Evaluate    $grpc_value.replace('_', '')    modules=builtins
    ${cli_short}=    Evaluate    $cli_value.replace('_', '')    modules=builtins
    IF    not $grpc_short.endswith($cli_short)
        Fail    The gRPC value "${grpc_value}" does not match the CLI value "${cli_value}"
    END
    RETURN    ${grpc_value}

IT COMMON - Grpc Get Nested Or Default
    [Documentation]    Read a field out of a nested gRPC response object, or a fallback value.

    ...              Used where the answer of the DUT does not carry every
    ...              field in every state, e.g. a boolean that protobuf leaves
    ...              out while it is false.

    [Arguments]    ${response}    ${path}    ${default}=${NONE}
    ${value}=    Evaluate
    ...    __import__('functools').reduce(lambda o, k: o.get(k, None), $path, $response)
    ...    modules=builtins
    IF    $value is None
        RETURN    ${default}
    END
    RETURN    ${value}

IT COMMON - Restore Grpc Configuration
    [Documentation]    Put a configuration back over gRPC and check that it took.

    ...              ${payload} is the JSON payload of the SET call, e.g.
    ...              {"pabConfig": {...}}, ${method} is the SET call and
    ...              ${get_method} is the call that reads the configuration
    ...              back. An empty payload means that nothing was set, so
    ...              there is nothing to restore.

    ...              ${path} is the path of the field that is checked after
    ...              the SET, e.g. ["pabConfig", "rpdPwrdThreshold"]. The
    ...              value of that field in the payload is the value it has
    ...              to carry afterwards.

    [Arguments]    ${proto}    ${method}    ${get_method}    ${payload}    ${path}=${EMPTY}
    # The payload is a JSON with double quotes in it, so it must not be put
    # into the condition as text.
    IF    $payload is None or $payload == ''
        Log    Nothing was set, so there is nothing to restore
        RETURN
    END
    ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}    ${payload}
    IT COMMON - Grpc Should Succeed    ${response}
    IF    $path
        ${after}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${get_method}
        ${wanted}=    Evaluate    json.loads($payload)    modules=json
        ${value}=    IT COMMON - Grpc Get Nested Or Default    ${after}    ${path}
        ${expected}=    IT COMMON - Grpc Get Nested Or Default    ${wanted}    ${path}
        ${ok}=    Evaluate    abs(float($value) - float($expected)) < 0.001    modules=builtins
        IF    not $ok
            Fail    The configuration was not restored: ${path} is "${value}", expected "${expected}".\nAnswer: ${after}
        END
    END
    RETURN    ${response}

IT COMMON - Wait For Grpc Nested Field Value
    [Documentation]    Poll a gRPC call until a field of the answer has a value.

    ...              ${proto} and ${method} are the call, ${path} is the path
    ...              of the field inside the answer, e.g.
    ...              ["pabStatus", "isCompleted"], and ${expected} is the value
    ...              the field has to reach. The answer of the last poll is
    ...              part of the failure message.

    [Arguments]    ${proto}    ${method}    ${path}    ${expected}    ${timeout}=${IT_WAIT_DEFAULT}    ${interval}=${IT_POLL_DEFAULT}
    ${end}=    Evaluate    time.time() + int($timeout)    modules=time
    ${last}=    Set Variable    ${EMPTY}
    WHILE    $end > time.time()
        ${response}=    IT COMMON - Grpcurl And Return Json    ${proto}    ${method}
        ${value}=    IT COMMON - Grpc Get Nested Or Default    ${response}    ${path}    default=${NONE}
        ${last}=    Set Variable    ${response}
        IF    $value is not None and "${value}" == "${expected}"
            RETURN    ${response}
        END
        Sleep    ${interval}
    END
    Fail    The gRPC call ${method} did not reach ${path} = "${expected}" within ${timeout}s. The last answer was:\n${last}
