import codecs
import json
import os
import re
import shlex
import socket
import time
from datetime import datetime

import paramiko

from robot.api import logger
import robot.utils.asserts
from robot.libraries.BuiltIn import BuiltIn


class ViperGnmi(object):
    """ViperGnmi is a Robot Framework test library for driving gNMI against the Viper eAMP.

    The control PC does NOT speak gNMI itself. A gNMI client host sits in the
    testbed with gnmic installed, so every keyword logs in there over SSH and
    runs gnmic against the DUT:

    | Control PC (Robot) | --SSH--> | gNMI client host | --gNMI--> | Viper eAMP |

    Call `Connect` once to open the SSH session, then every other keyword reuses
    it, which is why they do NOT take the settings themselves. Call `Close` in
    teardown. A session that died between two keywords is rebuilt automatically.

    === ssh_setting ===

    Argument ``ssh_setting`` defines how to reach the *gNMI client host*.

    Format must be defined as dictionary variables with the following key/value

    { "name": str, "host": str, "port": int, "username": str, "password": str, "timeout": int }.

    Examples:
    - { "name": gNMI_Client, "host": 1.1.1.1, "port": 22, "username": usr, "password": pwd, "timeout": 10 }

    === gnmi_setting ===

    Argument ``gnmi_setting`` defines the gNMI target, which is the DUT eAMP.

    Format must be defined as dictionary variables with the following key/value

    { "name": str, "host": str, "port": int, "insecure": bool, "timeout": int }.

    Examples:
    - { "name": DUT_EAMP_GNMI, "host": 2001:db8::1, "port": 9339, "insecure": True, "timeout": 0 }

    There are no credentials in here on purpose: gnmic reaches the Viper eAMP
    without -u / -p, and the gNMI server of the DUT does not check them.

    "timeout" is the default gNMI timeout for this target, see `Timeouts`.

    The eAMP address is only known at run time, so "host" in the variable file is
    a placeholder. One keyword in Suite Setup fills it in, the same one the SSH
    keywords rely on:

    | CABLEOS - Resolve DUT eAMP IPv6 | COS |

    It writes the host of this dictionary, the host of &{SSH_DUT_EAMP}, and the
    scalar ${DUT_EAMP_IPV6} for when a bare address is what you need.

    An IPv6 host is wrapped in brackets automatically, gnmic needs
    "[2001:db8::1]:9339" and the variable file holds the bare address.

    === gnmic on the client host ===

    Robot variable ``${GNMIC_BIN}`` says how gnmic is started on the gNMI client
    host. It is not only a path: it is the whole prefix, everything that comes
    before "-a", so a host that reaches gnmic through a container is a variable
    file change and not a library change.

    | ${GNMIC_BIN} | gnmic |
    | ${GNMIC_BIN} | docker run --network host --rm ghcr.io/openconfig/gnmic |

    The variable is optional, "gnmic" is used when it is not declared, so a
    testbed with gnmic on PATH has nothing to write down.

    `Raw And Return` does NOT read it. That keyword sends what it is given, so
    its command carries its own prefix.

    === PASS / FAIL and ERROR ===

    Two layers are judged separately, because they mean different things:

    - The SSH hop to the gNMI client host is *transport*. Anything wrong there
      (host down, bad credentials, missing setting key) is reported as ERROR<>,
      never as a gNMI verdict: the DUT was never asked.
    - The gNMI RPC itself is the verdict. gnmic exits non-zero when a request
      fails, so the exit status decides PASS<> / FAIL<> and the stderr text goes
      into the failure message.

    Whether the *content* of a response is correct is NOT judged here. Assert it
    in the test case, the keywords return the parsed response for that.

    === Timeouts ===

    Two different clocks, and they are NOT the same one:

    - ``timeout`` in `ssh_setting` bounds the TCP connect to the gNMI client
      host, nothing else. It has no say over how long a command may run.
    - ``resp_timeout`` on every RPC keyword bounds the gNMI call itself. It is
      passed to gnmic as --timeout, which is the gRPC deadline.

    ``resp_timeout`` defaults to None, which falls back to ``timeout`` in
    `gnmi_setting`, so a target can carry its own default and the test cases stay
    quiet about it. A value of 0 in either place means the --timeout flag is not
    passed at all and gnmic applies its own default of 10 seconds.

    The SSH channel is then given ``resp_timeout`` plus a few seconds of grace.
    That order matters: gnmic reaches its deadline first, prints the reason and
    exits non-zero, and the test sees a message naming the real problem instead
    of a bare "the command did not finish". The channel read is the safety net
    for gnmic hanging altogether, not the normal way a slow RPC ends.

    === Log files ===

    Every keyword appends the command and its response to
    ${RESULT_ROOT_PATH}/<SUITE NAME>/<log file>, where <log file> is the
    ``log_name`` of that keyword, or the main log assigned at `Connect` when
    ``log_name`` is not given.

    """

    __version__ = 'V1.1.0'
    __date__ = '2026/08/19'
    __author__ = "Jet Qian"
    ROBOT_LIBRARY_SCOPE = 'SUITE'

    # Fallback when ${GNMIC_BIN} is not declared: gnmic is on PATH of the client
    # host (/usr/local/bin/gnmic, v0.42.1).
    GNMIC_BIN = "gnmic"
    # "get" already answers in JSON, but "capabilities" answers in plain text
    # without this, so it is applied to every RPC to keep one parsing path.
    OUTPUT_FORMAT_ARGS = ("--format", "json")
    # gnmic parses --timeout as a Go duration and rejects a bare number
    # ("missing unit in duration"), while the setting files hold plain seconds.
    DURATION_UNIT = "s"
    # Seconds the SSH channel read is allowed on top of the gNMI timeout, so that
    # gnmic always reaches its own deadline first and gets to say why. Measured:
    # gnmic wraps up about 0.1s after the deadline.
    SSH_READ_GRACE = 5
    # What gnmic falls back to when --timeout is not passed. Only used to size the
    # channel read in that case, never sent as a flag.
    GNMIC_DEFAULT_TIMEOUT = 10

    def __init__(self):
        self._ssh_setting = None
        self._gnmi_setting = None
        self._connection = None
        self._subscription = None
        self._subscription_buffer = ""
        self._subscription_decoder = None
        self._subscription_stderr = ""
        self._subscription_log_name = None
        self._subscription_command = None
        # Default main log: every response lands here unless a log_name is given.
        file_timestamp = datetime.now().strftime("%m%d_%H%M%S")
        self._main_log_name = f"_gnmi_{file_timestamp}.log"
        self._var_checked = False

    @property
    def _result_root_path(self):
        return BuiltIn().get_variable_value("${RESULT_ROOT_PATH}")

    @property
    def _log_folder(self):
        # Log_Folder = ${RESULT_ROOT_PATH} / ${SUITE NAME}.rsplit('#')[-1]
        suite_full_name = BuiltIn().get_variable_value("${SUITE NAME}")
        suite_name = suite_full_name.rsplit('#')[-1]
        return os.path.join(self._result_root_path, suite_name)

    @property
    def _gnmic_bin(self):
        # Not every client host has gnmic as a plain binary on PATH: it may be a
        # container, e.g. "docker run --network host --rm ghcr.io/openconfig/gnmic".
        # ${GNMIC_BIN} carries the whole invocation prefix, so such a host is a
        # variable file change and not a library change. Deliberately NOT part of
        # _check_robot_variable: the variable is optional, missing is the normal
        # case and the class default covers it.
        value = BuiltIn().get_variable_value("${GNMIC_BIN}", self.GNMIC_BIN)
        return str(value).strip() or self.GNMIC_BIN

    # Check and Warn if pre-defined variables are not declared in robot framework by user.
    # One-shot on purpose: this must NOT run from __init__, because libdoc instantiates
    # the library outside any Robot execution context and BuiltIn() would raise there.
    def _check_robot_variable(self):
        if self._var_checked:
            return
        #${RESULT_ROOT_PATH}
        rslt = BuiltIn().get_variable_value("${RESULT_ROOT_PATH}")
        if rslt is None:
            robot.utils.asserts.fail("ERROR<>Can NOT find \"$RESULT_ROOT_PATH\" in robot")
        self._var_checked = True

    @staticmethod
    def _check_setting(setting, para_list, setting_name):
        # Missing keys are a testbed / variable file mistake, so they are ERROR<>
        # rather than a gNMI verdict.
        if not isinstance(setting, dict):
            robot.utils.asserts.fail(f"ERROR<>{setting_name} should be a dictionary, got \"{setting}\"")
        for para in para_list:
            if para not in setting.keys():
                robot.utils.asserts.fail(
                    f"ERROR<>{setting_name} should contain the following parameters \"{para_list}\"")

    @property
    def _is_connected(self):
        # 1. object exist
        if self._connection is None:
            return False
        # 2. transport exist and active
        transport = self._connection.get_transport()
        if transport is None or not transport.is_active():
            return False
        return True

    def connect(self, ssh_setting, gnmi_setting, main_log_name=None):
        """Open the SSH session to the gNMI client host and keep it for the following keywords.

        *Steps*

        1) Verify ``ssh_setting`` and ``gnmi_setting``

        2) Open the SSH connection to the gNMI client host and login

        Nothing is sent to the DUT here. The first gNMI traffic happens when a
        RPC keyword runs, so a failure in this keyword is always ERROR<>.

        *Arguments Detail*

        ``ssh_setting:``    Refer to `ssh_setting`

        ``gnmi_setting:``   Refer to `gnmi_setting`

        ``main_log_name:``  file name of the main gNMI log. Real path is
                            ${RESULT_ROOT_PATH}/<suite>/<main_log_name>. Every
                            keyword without its own log_name appends here.
                            Default is "_gnmi_<MMDD_hhmmss>.log".

        *Examples:*
        | Connect | ssh_setting=${SSH_GNMI_CLIENT} | gnmi_setting=${GNMI_DUT_EAMP} |
        | Connect | ssh_setting=${SSH_GNMI_CLIENT} | gnmi_setting=${GNMI_DUT_EAMP} | main_log_name=gnmi.log |
        """
        arg_info = f"ssh_setting={ssh_setting}, gnmi_setting={gnmi_setting}, main_log_name={main_log_name}"
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperGnmi - Connect : {arg_info}")

        self._check_robot_variable()
        self._check_setting(ssh_setting, ["name", "host", "port", "username", "password", "timeout"], "ssh_setting")
        self._check_setting(gnmi_setting, ["name", "host", "port"], "gnmi_setting")
        self._ssh_setting = ssh_setting
        self._gnmi_setting = gnmi_setting
        if main_log_name is not None:
            self._main_log_name = main_log_name
        # The DUT takes the TCP connection before its sshd can answer, so a
        # connection that is reset while the banner is read is a normal event
        # right after a reboot or while the amplifier is busy with something.
        #
        # The DUT also refuses the login for a while when its clock is behind
        # the date the password of the account was changed: PAM says "account
        # amp_admin has password changed in future" and denies the session.
        # The clock of the DUT jumps around (it starts at 1970 after a
        # reboot), so this happens now and then and lasts a minute or two.
        # The connect is therefore tried for about two minutes.
        attempts = 6
        for attempt in range(1, attempts + 1):
            try:
                self._open_session()
                return
            except AssertionError as error:
                if attempt == attempts:
                    raise
                logger.write(
                    f"the connect failed ({error}), trying again in 20s", 'WARN')
                time.sleep(20)

    def close(self):
        """Close the SSH session to the gNMI client host (teardown-safe).

        The settings given to `Connect` are kept, so a later keyword rebuilds the
        session by itself.

        *Examples:*
        | Close |
        """
        logger.console("\n\tViperGnmi - Close")
        self.stop_subscription()

        if not self._is_connected:
            logger.write("gNMI client SSH connection already disconnected or never established.", 'INFO')
            self._connection = None
            return

        try:
            self._connection.close()
            logger.write("gNMI client SSH connection closed.", 'INFO')
        except Exception as err:
            logger.write(f"Error while closing connection: {err}", 'WARN')
        finally:
            self._connection = None

    def capabilities_and_return(self, resp_timeout=None, log_name=None):
        """Send the gNMI Capabilities RPC and return the parsed response.

        Use it to see which models, encodings and gNMI version the DUT declares,
        typically as a pre-check before touching a model specific path.

        *Steps*

        1) Run "gnmic ... capabilities" on the gNMI client host

        2) Judge the gnmic exit status

        *Arguments Detail*

        ``resp_timeout:``   seconds the gNMI call may take, see `Timeouts`.
                            Default is None, which uses the target's own timeout.

        ``log_name:``       file name to append the command and response to. Real
                            path is ${RESULT_ROOT_PATH}/<suite>/<log_name>.
                            Default is the main log assigned at `Connect`.

        *RETURN* => the parsed response, a dict with "version", "supported-models"
        and "encodings"

        *Examples:*
        | ${rslt}= | Capabilities And Return |
        | ${rslt}= | Capabilities And Return | log_name=case_id.log |
        """
        arg_info = f"resp_timeout={resp_timeout}, log_name={log_name}"
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperGnmi - Capabilities And Return : {arg_info}")

        return self._rpc(["capabilities"], resp_timeout, log_name)

    def get_and_return(self, paths, encoding=None, values_only=False, resp_timeout=None, log_name=None):
        """Send the gNMI Get RPC for one or more paths and return the parsed response.

        *Steps*

        1) Run "gnmic ... get --path ..." on the gNMI client host

        2) Judge the gnmic exit status

        *Arguments Detail*

        ``paths:``          gNMI path, or a list of paths to read in one RPC.
                            An empty string reads the whole tree.

        ``encoding:``       Optional, passed to gnmic as --encoding. Default is
                            None, which leaves the gnmic default. The DUT
                            declares which encodings it supports, see
                            `Capabilities And Return`.

        ``values_only:``    Optional, default is False. True adds --values-only,
                            which drops the path and timestamp wrapper and
                            returns bare values.

        ``resp_timeout:``   seconds the gNMI call may take, see `Timeouts`.
                            Default is None, which uses the target's own timeout.

        ``log_name:``       file name to append the command and response to. Real
                            path is ${RESULT_ROOT_PATH}/<suite>/<log_name>.
                            Default is the main log assigned at `Connect`.

        *RETURN* => the parsed response, a list with one entry per path

        Careful with ``values_only`` and several paths at once: the values come
        back in a bare list with no path attached, so nothing tells you which
        value belongs to which path other than their order.

        *Examples:*
        | ${rslt}= | Get And Return | amp-identification |
        | ${rslt}= | Get And Return | amp-identification | values_only=${True} |
        | ${rslt}= | Get And Return | /us-profile/us-port-configuration[port=AMP_PORT_NORTH] |
        # read several paths in one RPC
        | @{paths}= | Create List | /north-port-monitor-status/rx-adc-input-power-dbmv-tcp | amp-identification |
        | ${rslt}= | Get And Return | ${paths} | log_name=case_id.log |
        """
        arg_info = (f"paths={paths}, encoding={encoding}, values_only={values_only}, "
                    f"resp_timeout={resp_timeout}, log_name={log_name}")
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperGnmi - Get And Return : {arg_info}")

        path_list = self._as_list(paths)
        if not path_list:
            robot.utils.asserts.fail("ERROR<>Get needs at least one path")

        rpc_args = ["get"]
        for one_path in path_list:
            rpc_args += ["--path", one_path]
        if encoding is not None:
            rpc_args += ["--encoding", encoding]
        if self._is_true(values_only):
            rpc_args.append("--values-only")
        return self._rpc(rpc_args, resp_timeout, log_name)

    def set_and_return(self, updates=None, replaces=None, deletes=None, resp_timeout=None, log_name=None):
        """Send the gNMI Set RPC and return the parsed response.

        All three kinds of operation travel in ONE Set RPC, because gNMI applies
        a Set atomically. That is why they are three arguments of one keyword
        instead of three keywords.

        *Steps*

        1) Run "gnmic ... set --update ... --replace ... --delete ..." on the
           gNMI client host

        2) Judge the gnmic exit status

        *Arguments Detail*

        ``updates:``        one "path:::type:::value" string, or a list of them.
                            This is the gnmic notation, so a command that already
                            works on the client host can be pasted as is.
                            ``type`` is what gnmic accepts, e.g. string / int /
                            bool / json.

        ``replaces:``       same notation as ``updates``, sent as --replace

        ``deletes:``        one path, or a list of paths, sent as --delete.
                            No type and no value here.

        ``resp_timeout:``   seconds the gNMI call may take, see `Timeouts`.
                            Default is None, which uses the target's own timeout.

        ``log_name:``       file name to append the command and response to. Real
                            path is ${RESULT_ROOT_PATH}/<suite>/<log_name>.
                            Default is the main log assigned at `Connect`.

        *RETURN* => the parsed response, which reports the result per path

        *Examples:*
        | ${rslt}= | Set And Return | updates=/us-profile/us-port-configuration[port=AMP_PORT_NORTH]/rlsp-dbmv:::int:::8 |
        # several updates in one RPC, the firmware upgrade case
        | @{ups}= | Create List | /software-upgrade/file-name:::string:::${fw_img} | /software-upgrade/update-type:::string:::UPDATE_PUSH_ONLY |
        | ${rslt}= | Set And Return | updates=${ups} | log_name=case_id.log |
        | ${rslt}= | Set And Return | deletes=/some/path |
        """
        arg_info = (f"updates={updates}, replaces={replaces}, deletes={deletes}, "
                    f"resp_timeout={resp_timeout}, log_name={log_name}")
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperGnmi - Set And Return : {arg_info}")

        rpc_args = ["set"]
        for flag, values in (("--update", updates), ("--replace", replaces), ("--delete", deletes)):
            for one_value in self._as_list(values):
                rpc_args += [flag, one_value]
        if len(rpc_args) == 1:
            robot.utils.asserts.fail("ERROR<>Set needs at least one of updates / replaces / deletes")
        return self._rpc(rpc_args, resp_timeout, log_name)

    def start_subscription(self, path, timeout=15, log_name=None):
        """Start an ON_CHANGE subscription and wait for its sync response."""
        self._ensure_connected()
        if self._subscription is not None:
            raise RuntimeError("A gNMI subscription is already active")
        argv = self._gnmic_argv(
            ["sub", "--stream-mode=ON_CHANGE", "--path", path, "--updates-only"], 0)
        command = " ".join(shlex.quote(arg) for arg in argv)
        _, stdout, _ = self._connection.exec_command(command)
        self._subscription = stdout.channel
        self._subscription_buffer = ""
        self._subscription_decoder = codecs.getincrementaldecoder("utf-8")()
        self._subscription_stderr = ""
        self._subscription_log_name = log_name
        self._subscription_command = command
        try:
            response = self._next_subscription_response(float(timeout))
            if response.get("sync-response") is not True:
                raise AssertionError(f"Expected subscription sync response, got: {response}")
        except (AssertionError, RuntimeError, TimeoutError, ValueError, OSError):
            self.stop_subscription()
            raise

    def next_subscription_response(self, timeout=120):
        """Return the next complete JSON response from the active subscription."""
        return self._next_subscription_response(float(timeout))

    def stop_subscription(self):
        """Close the active subscription, including after a failed test."""
        if self._subscription is not None:
            self._subscription.close()
            self._subscription = None

    def _next_subscription_response(self, timeout):
        channel = self._subscription
        if channel is None:
            raise RuntimeError("No gNMI subscription is active")
        deadline = time.monotonic() + timeout
        decoder = json.JSONDecoder()
        while time.monotonic() < deadline:
            text = self._subscription_buffer.lstrip()
            if text:
                try:
                    response, end = decoder.raw_decode(text)
                except json.JSONDecodeError:
                    pass
                else:
                    self._subscription_buffer = text[end:]
                    if not isinstance(response, dict):
                        raise ValueError(f"Unexpected subscription response: {response}")
                    self._save_log(self._subscription_log_name,
                                   f"\n{self._subscription_command}\n{json.dumps(response)}")
                    return response
            if channel.recv_stderr_ready():
                self._subscription_stderr += channel.recv_stderr(32768).decode("utf-8", errors="replace")
            if channel.recv_ready():
                self._subscription_buffer += self._subscription_decoder.decode(channel.recv(32768))
                continue
            if channel.exit_status_ready():
                raise RuntimeError(
                    f"gNMI subscription exited ({channel.recv_exit_status()}): {self._subscription_stderr}")
            time.sleep(0.1)
        raise TimeoutError(f"gNMI subscription timed out after {timeout}s: {self._subscription_stderr}")

    def raw_and_return(self, cmd_str, resp_timeout=None, log_name=None):
        """Run a command on the gNMI client host as given and return its output.

        The escape hatch for anything the other keywords do not cover. Nothing is
        added and nothing is quoted, ``cmd_str`` reaches the remote shell exactly
        as written, so the caller owns the quoting. It does not even have to be a
        gnmic command.

        The output is not touched either: it comes back as text, exactly as the
        command printed it. That is the point of this keyword, it is the way to
        read a full response without the library reshaping it. Use
        `Get And Return` or `Capabilities And Return` when a parsed response is
        what you want. The exit status is still judged.

        *Steps*

        1) Run ``cmd_str`` on the gNMI client host

        2) Judge the exit status

        *Arguments Detail*

        ``cmd_str:``        command to run on the gNMI client host

        ``resp_timeout:``   seconds the command may take, see `Timeouts`.
                            Default is None, which uses the target's own timeout.
                            No --timeout is added to ``cmd_str``, so when the
                            command carries a timeout of its own, this argument
                            has to be at least as large. The command is not read,
                            so nothing can line the two up for you: leave them
                            mismatched and the channel read cuts a command that
                            was still working.

        ``log_name:``       file name to append the command and response to. Real
                            path is ${RESULT_ROOT_PATH}/<suite>/<log_name>.
                            Default is the main log assigned at `Connect`.

        *RETURN* => the raw text the command printed, never parsed

        *Examples:*
        | ${rslt}= | Raw And Return | gnmic version |
        | ${rslt}= | Raw And Return | gnmic -a [::1]:9339 --insecure get --path / | log_name=case_id.log |
        """
        arg_info = f"cmd_str={cmd_str}, resp_timeout={resp_timeout}, log_name={log_name}"
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperGnmi - Raw And Return : {arg_info}")

        self._ensure_connected()
        rc, stdout, stderr = self._exec(cmd_str, resp_timeout)
        self._judge(cmd_str, rc, stdout, stderr, log_name)
        return stdout

    def wait_for_connection(self, timeout=300, interval=5):
        """Wait until the SSH session to the gNMI client host is up again.

        A reboot takes the session down, but the transport does not notice it
        right away: the next command then runs on a dead channel and fails
        with an exit status of -1 instead of a connection error. This closes
        the session and opens it again, and keeps trying until it works: the
        SSH service of the DUT accepts the TCP connection before it is ready
        to speak SSH, so the first attempts are reset by the peer.

        *Arguments Detail*

        ``timeout:``    how long to wait for the session in seconds
        ``interval:``   how long to wait between two attempts in seconds

        *Examples:*
        | Wait For Connection | timeout=300 | interval=5 |
        """
        logger.console("\n\tViperGnmi - Wait For Connection")
        logger.write(
            f"[Arguments]: timeout={timeout}, interval={interval}", 'INFO')

        if self._ssh_setting is None:
            robot.utils.asserts.fail("ERROR<>No gNMI client session, call Connect first")

        end = time.time() + float(timeout)
        while True:
            try:
                self._open_session()
                logger.write("PASS<>The gNMI client session is up", 'INFO')
                return True
            except Exception as error:
                if time.time() >= end:
                    robot.utils.asserts.fail(
                        f"ERROR<>The gNMI client session did not come up within {timeout}s: {error}")
                logger.write(
                    f"the gNMI client session is not up yet ({error}), waiting {interval}s", 'INFO')
                time.sleep(float(interval))

    def _open_session(self):
        # Build the session from the setting stored by "Connect". Every failure
        # here is transport, so it is ERROR<> and never a gNMI verdict.
        setting = self._ssh_setting
        target = setting.get('name') or setting.get('host')
        try:
            self.close()
            connection = paramiko.SSHClient()
            connection.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            # Robot passes every &{dict} value as a string, but paramiko needs an
            # int port and does arithmetic on timeout (time.time() + timeout).
            connection.connect(
                hostname=setting['host'],
                port=int(setting['port']),
                username=setting['username'],
                password=setting['password'],
                timeout=float(setting['timeout']),
            )
            self._connection = connection
            # Detect a silently dropped link in tens of seconds instead of
            # waiting for the TCP timeout.
            connection.get_transport().set_keepalive(30)
            logger.write(f"Connected to gNMI client host {target}", 'INFO')
        except socket.timeout:
            robot.utils.asserts.fail(
                f"ERROR<>Connect to gNMI client host {target} time out {setting.get('timeout')}.")
        except paramiko.SSHException as ssh_exception:
            robot.utils.asserts.fail(
                f"ERROR<>Connect to gNMI client host {target} fail, SSH Error : {ssh_exception}")
        except Exception as err:
            robot.utils.asserts.fail(
                f"ERROR<>Connect to gNMI client host {target} fail, Unexpected error {err}")

    def _ensure_connected(self):
        # Called by every RPC keyword: the session is kept open across tests
        # (SUITE scope), so it can die between two keywords.
        if self._ssh_setting is None:
            robot.utils.asserts.fail("ERROR<>No gNMI client session, call Connect first")
        if self._is_connected:
            return
        logger.write("gNMI client SSH connection is down, reconnecting.", 'WARN')
        self._open_session()

    @staticmethod
    def _as_list(value):
        # Robot hands over a bare string for a single item and a list for many,
        # so both are accepted everywhere and normalised here.
        if value is None:
            return []
        if isinstance(value, str):
            return [value]
        return list(value)

    @staticmethod
    def _is_true(value):
        # Robot passes ${True} as a bool but a plain cell as the string "True".
        if isinstance(value, str):
            return value.strip().lower() in ("true", "yes", "1")
        return bool(value)

    def _gnmi_timeout(self, resp_timeout):
        # The one number both clocks are derived from. None means the keyword did
        # not say, so the target's own default applies; 0 anywhere means "do not
        # pass --timeout at all" and gnmic falls back to its 10s.
        value = resp_timeout
        if value is None:
            value = self._gnmi_setting.get('timeout')
        if value is None:
            return 0
        try:
            number = float(value)
        except (TypeError, ValueError):
            robot.utils.asserts.fail(f"ERROR<>timeout should be a number, got \"{value}\"")
        # Robot hands over "10", and "10s" reads better in the command than "10.0s".
        return int(number) if number == int(number) else number

    def _ssh_read_timeout(self, resp_timeout):
        # gnmic has to hit its deadline before the channel read gives up, so that
        # its own error survives instead of being replaced by ours.
        value = self._gnmi_timeout(resp_timeout)
        if value <= 0:
            value = self.GNMIC_DEFAULT_TIMEOUT
        return value + self.SSH_READ_GRACE

    @classmethod
    def _duration(cls, value):
        # gnmic reads --timeout as a Go duration and rejects a bare number with
        # "missing unit in duration", while the setting files hold plain seconds.
        text = str(value).strip()
        if re.fullmatch(r'\d+(\.\d+)?', text):
            return f"{text}{cls.DURATION_UNIT}"
        return text

    @property
    def _gnmi_target(self):
        # gnmic wants "[2001:db8::1]:9339" for IPv6 while the variable file holds
        # the bare address, and a host that already carries brackets is left alone.
        host = str(self._gnmi_setting['host']).strip()
        port = self._gnmi_setting['port']
        if ":" in host and not host.startswith("["):
            host = f"[{host}]"
        return f"{host}:{port}"

    def _gnmic_argv(self, rpc_args, resp_timeout):
        # Global flags first, then the RPC and its own flags. Everything is a
        # separate element so that _rpc can quote each one on its own, which is
        # also why the prefix is split here: "docker run --network host --rm
        # ghcr.io/openconfig/gnmic" is several words and quoting it whole would
        # turn it into one command name that does not exist.
        # No -u / -p: gnmic reaches the eAMP without credentials, see `gnmi_setting`.
        setting = self._gnmi_setting
        argv = shlex.split(self._gnmic_bin)
        argv += ["-a", self._gnmi_target]
        if self._is_true(setting.get('insecure', True)):
            argv.append("--insecure")
        argv += list(self.OUTPUT_FORMAT_ARGS)
        # Never send "--timeout 0s": that is a deadline which has already expired,
        # so every command would fail. Zero means "leave the flag out".
        gnmi_timeout = self._gnmi_timeout(resp_timeout)
        if gnmi_timeout > 0:
            argv += ["--timeout", self._duration(gnmi_timeout)]
        return argv + [str(one_arg) for one_arg in rpc_args]

    def _exec(self, cmd_str, resp_timeout):
        # One exec channel per command. The channel is kept in a local so that a
        # long running RPC (Subscribe, later) can hold on to it instead of being
        # forced to read until EOF here.
        # The read is deliberately slower than the gNMI deadline, so reaching this
        # timeout means gnmic itself never came back, not that the RPC was slow.
        read_timeout = self._ssh_read_timeout(resp_timeout)
        channel = None
        try:
            stdin, stdout, stderr = self._connection.exec_command(cmd_str, timeout=float(read_timeout))
            channel = stdout.channel
            out = stdout.read().decode('utf-8', errors='replace')
            err = stderr.read().decode('utf-8', errors='replace')
            rc = channel.recv_exit_status()
            return rc, out, err
        except socket.timeout:
            # SSH itself is healthy, the command did not finish in time, so this
            # is a gNMI verdict and not a transport ERROR<>. Close the channel so
            # the remote process does not keep running unattended.
            if channel is not None:
                channel.close()
            return None, '', f"Timeout {read_timeout}s reached while waiting for the command to finish"
        except Exception as err:
            robot.utils.asserts.fail(
                f"ERROR<>Unexpected error while running a command on the gNMI client host: {err}")

    def _rpc(self, rpc_args, resp_timeout, log_name):
        # Shared by every gNMI keyword: build, run, log, judge, parse.
        self._ensure_connected()
        argv = self._gnmic_argv(rpc_args, resp_timeout)
        # The command crosses SSH into a remote shell, so every element is quoted
        # here. gNMI paths carry shell metacharacters for real, e.g.
        # "/us-profile/us-port-configuration[port=AMP_PORT_NORTH]" and the
        # bracketed IPv6 target are both glob patterns to a shell.
        cmd_str = " ".join(shlex.quote(one_arg) for one_arg in argv)
        logger.write(f"[gnmic Command]: {cmd_str}", 'DEBUG')

        rc, stdout, stderr = self._exec(cmd_str, resp_timeout)
        self._judge(cmd_str, rc, stdout, stderr, log_name)
        return self._parse_json(stdout)

    def _judge(self, cmd_str, rc, stdout, stderr, log_name):
        # gnmic exits non-zero when a request fails, so the exit status is the
        # verdict and stderr explains it. Parsing is left to the caller, because
        # Raw And Return must hand back untouched text.
        log_content = f"\n{cmd_str}\n{stdout}"
        if stderr:
            log_content += f"\n{stderr}"
        self._save_log(log_name, log_content)
        logger.write(stdout, 'DEBUG')

        if rc == 0:
            flag = "PASS<>gnmic exit status 0"
        elif rc is None:
            flag = f"FAIL<>{stderr.strip()}"
        else:
            flag = f"FAIL<>gnmic exit status {rc} : {stderr.strip()}"

        judge_flag, judge_content = self._log_judgement(flag)
        if not judge_flag:
            robot.utils.asserts.fail(f"Run \"{cmd_str}\" => {judge_content}")
        return self._parse_json(stdout)

    @staticmethod
    def _parse_json(text):
        # gnmic with --format json answers with one JSON document, including
        # --values-only and several paths at once, so one load covers every case.
        # Raw And Return may carry something else, hence the fallback.
        stripped = text.strip()
        if not stripped:
            return stripped
        try:
            return json.loads(stripped)
        except ValueError as err:
            logger.write(f"Response is not JSON, returning it as text : {err}", 'WARN')
            return text

    def _format_output(self, result: str):
        display_t = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}]"
        timestamped_output = "\n".join([f"{display_t} {ln.rstrip()}" for ln in result.strip().splitlines()])
        return timestamped_output + "\n"

    def _save_log(self, log_name, log_content):
        # Append to the given log file, or to the main log when no name is given.
        # An empty name counts as no name, so a caller that has no log file of
        # its own can pass an empty string.
        if not log_name:
            log_path = os.path.join(self._log_folder, self._main_log_name)
        else:
            log_path = os.path.join(self._log_folder, log_name)
        os.makedirs(self._log_folder, exist_ok=True)
        with open(log_path, "ab") as file:
            file.write(self._format_output(log_content).encode('utf-8'))

    def _log_judgement(self, content):
        match_obj = re.search(r'PASS<>(.*)', content)
        if match_obj:
            return 1, match_obj.group(0)

        match_obj = re.search(r'FAIL<>(.*)', content)
        if match_obj:
            return 0, match_obj.group(0)

        return 0, "ERROR<>Can NOT find judgement content in log"


def _library_info(job):
    obj = ViperGnmi
    md_info = obj.__dict__
    if job == '-v':
        print(md_info["__version__"])
    elif job == '-l':
        print(f"{obj.__name__:30s}: {md_info['__version__']:6s} | {md_info['__date__']:8s} | {md_info['__author__']:10s}")
    elif job == '-h':
        print(f"Library Name : {obj.__name__}")
        print(f"Library Version : {md_info['__version__']}")
        print(f"Library Author : {md_info['__author__']}")
        method_list = [method for method in md_info.keys() if callable(md_info[method])]
        method_list = [method for method in method_list if (method.startswith('__') or method.startswith('_')) is False]
        print("Available Custom Keywords : ")
        for x in method_list:
            print(f"\t{obj.__name__}.{x}")

        property_list = [pro for pro in md_info.keys() if isinstance(md_info[pro], property)]
        if property_list:
            print("Property value :")
            for x in property_list:
                print(f"\t{x}")
        else:
            pass


if __name__ == '__main__':
    import sys
    # Show version only when get -v
    # Show version / date / author when get -l
    # Other situation show full library info
    if len(sys.argv) == 2:
        if sys.argv[1].lower() == "-v":
            _library_info("-v")
        elif sys.argv[1].lower() == "-l":
            _library_info("-l")
        else:
            _library_info("-h")
