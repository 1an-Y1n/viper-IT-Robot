import os
import re
import socket
import time
from datetime import datetime

import paramiko

from robot.api import logger
import robot.utils.asserts
from robot.libraries.BuiltIn import BuiltIn


# Keep the first KEXINIT small for older DUT SSH servers that may drop large
# initial packets before key exchange negotiation can begin.
DUT_DISABLED_KEX = (
    "mlkem768x25519-sha256",
    "sntrup761x25519-sha512@openssh.com",
)


class _LineStamper(object):
    """Render received text as timestamped lines: "[YYYY-MM-DD HH:MM:SS.mmm] <line>".

    A line is stamped with the moment the chunk carrying its newline arrived, so
    lines that share a timestamp genuinely arrived together. Chunk boundaries do
    not match line boundaries (the command echo comes back character by
    character), hence the pending buffer: a line is only emitted once its
    newline shows up.
    """

    def __init__(self):
        self._lines = []
        self._pending = ''
        self._last_stamp = None

    @staticmethod
    def _now():
        return datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]

    def feed(self, text):
        stamp = self._now()
        self._last_stamp = stamp
        self._pending += text
        parts = self._pending.split('\n')
        self._pending = parts.pop()          # keep the incomplete tail
        for line in parts:
            self._lines.append(f"[{stamp}] {line.rstrip(chr(13))}")

    def render(self):
        lines = list(self._lines)
        if self._pending:
            # e.g. the trailing prompt, which never carries a newline
            stamp = self._last_stamp if self._last_stamp is not None else self._now()
            lines.append(f"[{stamp}] {self._pending}")
        if not lines:
            return ''
        return "\n".join(lines) + "\n"


class ViperSSH(object):
    # SSH (paramiko) interactive-shell library for Viper management port.
    # Ported from the proven SSHConnection class used in PAB_LongRun, refactored
    # into Robot Framework style (SUITE scope, robot.api.logger, PASS<>/FAIL<>).
    #
    # Three interface levels are supported. FDX is the login default and acts as
    # the hub: every transition goes "back to FDX first, then into the target".
    # One instance = one connection pinned to one level; use "WITH NAME" to open
    # several instances (one per level), or keep a single instance and switch
    # with the "Ensure Level" keyword.
    #
    # The session is opened once by "Connect" and kept for the whole suite. A
    # session that died in between is rebuilt by the keywords themselves and put
    # back on the level this instance was pinned to, so callers never have to
    # check the connection.
    __version__ = 'V1.0.3'
    __date__ = '2026/08/04'
    __author__ = "Jet Qian"
    ROBOT_LIBRARY_SCOPE = 'SUITE'

    # "enter" / "exit" hold the exact string to send (terminator included),
    # because HAL is left with Ctrl+D (EOF) which must NOT carry a newline.
    # FDX has no "exit": sending exit at FDX drops the whole SSH session, so
    # keeping it None structurally prevents navigation from ever doing that.
    LEVELS = {
        "FDX": {"prompt": "FDX-AMP>$ ", "enter": None, "exit": None},
        "ROOT": {"prompt": "bash-3.2# ", "enter": "debug shell\n", "exit": "exit\n"},
        "HAL": {"prompt": "hal> ", "enter": "debug hal\n", "exit": "\x04"},
    }

    def __init__(self):
        self._setting = None
        self._level = "FDX"
        self._connection = None
        self._channel = None
        # Default main log: every buffer lands here unless a log_name is given.
        file_timestamp = datetime.now().strftime("%m%d_%H%M%S")
        self._main_log_name = f"_ssh_{file_timestamp}.log"
        self._var_checked = False
        # True when the DUT closed the session under a running command.
        self._connection_lost = False

    @property
    def _result_root_path(self):
        return BuiltIn().get_variable_value("${RESULT_ROOT_PATH}")

    @property
    def _log_folder(self):
        # Log_Folder = ${RESULT_ROOT_PATH} / ${SUITE NAME}.rsplit('#')[-1]
        suite_full_name = BuiltIn().get_variable_value("${SUITE NAME}")
        suite_name = suite_full_name.rsplit('#')[-1]
        return os.path.join(self._result_root_path, suite_name)

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

    def connect(self, ssh_setting, level="FDX", main_log_name=None):
        """Open an SSH connection, then navigate to the given interface level.

        *Steps*

        1) Open SSH connection and an interactive shell channel

        2) Drain the login banner until the FDX prompt is seen

        3) Navigate to ``level`` if it is not FDX

        *Arguments Detail*

        ``ssh_setting:``    dict with keys host / port / username / password / timeout
                            (the "prompt" key is NOT needed, the level decides the prompt).

        ``level:``          FDX / ROOT / HAL, default is FDX. It is stored as this
                            instance's level and restored automatically on reconnect.

        ``main_log_name:``  file name of the main console log. Real path is
                            ${RESULT_ROOT_PATH}/<suite>/<main_log_name>. Every Send /
                            Send And Return without its own log_name appends here.
                            Default is "_ssh_<MMDD_hhmmss>.log".

        *Examples:*
        | Connect | ssh_setting=${SSH.MNGT} |
        | Connect | ssh_setting=${SSH.MNGT} | level=ROOT | main_log_name=root_ssh.log |
        """
        arg_info = f"ssh_setting={ssh_setting}, level={level}, main_log_name={main_log_name}"
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperSSH - Connect : {arg_info}")

        self._check_robot_variable()
        self._check_level(level)
        self._setting = ssh_setting
        self._level = level
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

    def _open_session(self):
        # Build the session from the setting stored by "Connect", then put it back
        # on this instance's level: a freshly built session always lands on FDX.
        # Shared by Connect and by the automatic reconnect in _ensure_connected.
        setting = self._setting
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
                disabled_algorithms={"kex": DUT_DISABLED_KEX},
            )
            self._connection = connection
            self._invoke()
            # Detect a silently dropped link in tens of seconds instead of
            # waiting for the TCP timeout.
            connection.get_transport().set_keepalive(30)
            msg = "PASS<>Connect to SSH"
        except socket.timeout:
            msg = f"FAIL<>Connect to {target} time out {setting.get('timeout')}."
        except paramiko.SSHException as ssh_exception:
            msg = f"FAIL<>Connect to {target} fail, SSH Error : {ssh_exception}"
        except Exception as e:
            msg = f"FAIL<>Connect to {target} fail, Unexpected error {e}"

        judge_flag, judge_content = self._log_judgement(msg)
        if judge_flag:
            logger.write(judge_content, 'INFO')
        else:
            robot.utils.asserts.fail(judge_content)

        # Consume the login banner so the buffer starts from a clean baseline,
        # otherwise level detection would match against leftover banner text.
        self._drain_to_prompt(self.LEVELS["FDX"]["prompt"])
        if self._level != "FDX":
            self._goto_level(self._level)

    def _ensure_connected(self):
        # Called by every keyword that talks to the channel: the session is kept
        # open across tests (SUITE scope), so it can die between two keywords.
        if self._setting is None:
            robot.utils.asserts.fail("FAIL<>No SSH session, call Connect first")
        if self._is_connected and self._channel is not None:
            return
        logger.write("SSH connection is down, reconnecting.", 'WARN')
        # _open_session navigates back to self._level for us
        self._open_session()

    def ensure_level(self, level):
        """Navigate to the given interface level, whichever level we are on now.

        All transitions go through FDX: leave the current level back to FDX first,
        then enter the target level.

        *Arguments Detail*

        ``level:``      FDX / ROOT / HAL. It becomes this instance's level, so a
                        later reconnect restores it.

        *Examples:*
        | Ensure Level | ROOT |
        | Ensure Level | HAL |
        """
        arg_info = f"level={level}"
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperSSH - Ensure Level : {arg_info}")

        self._check_level(level)
        self._ensure_connected()
        self._goto_level(level)
        self._level = level
        logger.write(f"PASS<>Now at level {level}", 'INFO')

    def wait_for_connection(self, timeout=300, interval=10):
        """Wait until the DUT answers on the SSH channel again.

        A reboot takes the session down. The next keyword that talks to the
        channel rebuilds the session by itself, but the connect gives up after
        the connect timeout (10 s), which is much shorter than the boot of the
        DUT. This keyword waits for the DUT to come back instead.

        *Arguments Detail*

        ``timeout:``    how long to wait for the DUT in seconds
        ``interval:``   how long to wait between two attempts in seconds

        *Examples:*
        | Wait For Connection | timeout=300 | interval=10 |
        """
        logger.console("\n\tViperSSH - Wait For Connection")
        logger.write(
            f"[Arguments]: timeout={timeout}, interval={interval}", 'INFO')

        end = time.time() + float(timeout)
        while True:
            try:
                self._open_session()
                logger.write("PASS<>The DUT is back", 'INFO')
                return True
            except Exception as error:
                if time.time() >= end:
                    robot.utils.asserts.fail(
                        f"FAIL<>The DUT did not come back within {timeout}s: {error}")
                logger.write(
                    f"the DUT is not back yet ({error}), waiting {interval}s", 'INFO')
                time.sleep(float(interval))

    def get_current_level(self):
        """Detect and return the interface level the session is currently on.

        RETURN => "FDX" / "ROOT" / "HAL"

        *Examples:*
        | ${level}= | Get Current Level |
        """
        logger.console("\n\tViperSSH - Get Current Level")

        if self._channel is None:
            robot.utils.asserts.fail("FAIL<>SSH channel not established, call Connect first")
        level = self._detect_level()
        logger.write(f"PASS<>Current level is {level}", 'INFO')
        return level

    def send(self, cmd_str, prompt=None, resp_timeout=5, log_name=None):
        """Send a command and wait for prompt, judged as PASS<>/FAIL<>.

        This keyword does NOT check the current level. Call "Ensure Level" first
        when the command belongs to another interface level.

        This keyword is intended for simple CLI operations.
        If your command might trigger a lengthy process on the DUT
        (e.g., "reboot," "load default," or "firmware upgrade" commands),
        make sure you can manage the process flow accordingly.

        *Arguments Detail*

        ``cmd_str:``     command to send over the interactive shell

        ``prompt:``         waiting prompt, default is the prompt of this instance's level

        ``resp_timeout:``   seconds to wait for the prompt (default 5)

        ``log_name:``       file name to append the received buffer to. Real path is
                            ${RESULT_ROOT_PATH}/<suite>/<log_name>. Default is the main
                            log assigned at Connect.

        *Examples:*
        | Send | uptime |
        | Send | debug sc_cli get_pab_status | resp_timeout=10 | log_name=pab.log |
        """
        arg_info = f"cmd_str={cmd_str}, prompt={prompt}, resp_timeout={resp_timeout}, log_name={log_name}"
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperSSH - Send : {arg_info}")

        self._ensure_connected()
        flag, buff, stamped = self._cmd_recv_with_retry(cmd_str, prompt, resp_timeout)
        # logger.write(buff, 'DEBUG')
        self._save_log(log_name, stamped)
        judge_flag, judge_content = self._log_judgement(flag)
        if judge_flag:
            logger.write(f"Send \"{cmd_str}\" => {judge_content}", 'INFO')
        else:
            robot.utils.asserts.fail(f"Send \"{cmd_str}\" => {judge_content}")

    def send_and_return(self, cmd_str, prompt=None, resp_timeout=5, log_name=None):
        """Send a command, wait for prompt, and return the received buffer.

        This keyword does NOT check the current level. Call "Ensure Level" first
        when the command belongs to another interface level.

        This keyword is intended for simple CLI operations.
        If your command might trigger a lengthy process on the DUT
        (e.g., "reboot," "load default," or "firmware upgrade" commands),
        make sure you can manage the process flow accordingly.

        *Arguments Detail*

        ``cmd_str:``     command to send over the interactive shell

        ``prompt:``         waiting prompt, default is the prompt of this instance's level

        ``resp_timeout:``   seconds to wait for the prompt (default 5)

        ``log_name:``       file name to append the received buffer to. Real path is
                            ${RESULT_ROOT_PATH}/<suite>/<log_name>. Default is the main
                            log assigned at Connect.

        RETURN => return all received buffer

        *Examples:*
        | ${out}= | Send And Return | uptime |
        | ${out}= | Send And Return | uptime | log_name=uptime.log |
        """
        arg_info = f"cmd_str={cmd_str}, prompt={prompt}, resp_timeout={resp_timeout}, log_name={log_name}"
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperSSH - Send And Return : {arg_info}")

        self._ensure_connected()
        flag, buff, stamped = self._cmd_recv_with_retry(cmd_str, prompt, resp_timeout)
        logger.write(buff, 'DEBUG')
        self._save_log(log_name, stamped)
        judge_flag, judge_content = self._log_judgement(flag)
        if judge_flag:
            return buff
        else:
            robot.utils.asserts.fail(f"Send \"{cmd_str}\" => {judge_content}")

    def send_and_return_buffer(self, cmd_str, prompt=None, resp_timeout=5, log_name=None):
        """Send a command, wait for the prompt, and return the received buffer.

        The buffer is returned even when the prompt did not come in time, so a
        caller can look at what the DUT answered instead of getting nothing
        but a timeout. Use "Send And Return" when the prompt has to be there.

        *Arguments Detail*

        ``cmd_str:``     command to send over the interactive shell

        ``prompt:``         waiting prompt, default is the prompt of this instance's level

        ``resp_timeout:``   seconds to wait for the prompt (default 5)

        ``log_name:``       file name to append the received buffer to

        RETURN => return all received buffer
        """
        arg_info = f"cmd_str={cmd_str}, prompt={prompt}, resp_timeout={resp_timeout}, log_name={log_name}"
        logger.write(f"[Arguments]: {arg_info}", 'INFO')
        logger.console(f"\n\tViperSSH - Send And Return Buffer : {arg_info}")

        self._ensure_connected()
        flag, buff, stamped = self._cmd_recv_with_retry(cmd_str, prompt, resp_timeout)
        logger.write(buff, 'DEBUG')
        self._save_log(log_name, stamped)
        logger.write(f"Send \"{cmd_str}\" => {flag}", 'INFO')
        return buff

    def connect_and_return_banner(self, ssh_setting, timeout=10):
        """Open an SSH connection and return the login banner of the DUT.

        The banner of a login banner shows up in the banner of a new session,
        e.g. the one that "configure banner login" sets. The server sends it
        as the SSH message USERAUTH_BANNER, and paramiko does not read that
        message on a client connection, so the transport is built by hand here
        and the message is caught in it. The connection is closed again, so
        the session of the suite is not touched.

        *Arguments Detail*

        ``ssh_setting:``    dict with keys host / port / username / password / timeout

        ``timeout:``        seconds to wait for the handshake of the new session

        RETURN => the banner of the new session, an empty text when there is none
        """
        self._check_robot_variable()
        banner = []

        def catch_banner(message):
            banner.append(message.get_string())

        sock = socket.create_connection(
            (ssh_setting['host'], int(ssh_setting['port'])),
            float(ssh_setting['timeout']))
        transport = paramiko.Transport(
            sock, disabled_algorithms={"kex": DUT_DISABLED_KEX})
        transport._handler_table[paramiko.common.MSG_USERAUTH_BANNER] = catch_banner
        try:
            transport.start_client(timeout=float(timeout))
            transport.auth_password(ssh_setting['username'], ssh_setting['password'])
            return "".join(
                item.decode('utf-8', errors='ignore') if isinstance(item, bytes) else item
                for item in banner)
        finally:
            transport.close()

    def close(self):
        """Close the interactive channel then the SSH connection (teardown-safe).

        The instance's level and setting are kept, so the next keyword rebuilds
        the session by itself and lands back on that level.

        *Examples:*
        | Close |
        """
        logger.console("\n\tViperSSH - Close")

        if not self._is_connected:
            logger.write("SSH connection already disconnected or never established.", 'INFO')
            self._channel = None
            self._connection = None
            return

        # 1. close channel (child resource) first
        if self._channel:
            try:
                self._channel.close()
                logger.write("SSH channel closed.", 'INFO')
            except Exception as e:
                logger.write(f"Error while closing channel: {e}", 'WARN')
            finally:
                self._channel = None

        # 2. close connection (parent resource)
        if self._connection:
            try:
                self._connection.close()
                logger.write("SSH connection closed.", 'INFO')
            except Exception as e:
                logger.write(f"Error while closing connection: {e}", 'WARN')
            finally:
                self._connection = None

    def _check_level(self, level):
        if level not in self.LEVELS:
            robot.utils.asserts.fail(f"FAIL<>Unknown level \"{level}\", should be one of {list(self.LEVELS.keys())}")

    def _invoke(self):
        channel = self._connection.invoke_shell()
        channel.settimeout(5)
        self._channel = channel

    @staticmethod
    def _matched_prompt(buff, prompts):
        # Trailing whitespace is ignored on both sides: a prompt written in a
        # .robot file loses its trailing space (Robot strips it from a cell, and
        # even the "\ " escape does not survive), so requiring an exact tail
        # would make every hand written prompt time out for an invisible reason.
        tail = buff.rstrip()
        for one_prompt in prompts:
            if tail.endswith(one_prompt.rstrip()):
                return one_prompt
        return None

    def _read_until(self, prompts, timeout):
        # Read until the buffer ends with any prompt in "prompts".
        # Returns (matched_prompt or None, raw_buff, timestamped_text). An EOF
        # means the remote closed the session, so the connection is dropped to
        # force a rebuild next time.
        buff = ''
        stamper = _LineStamper()
        matched = None
        # resp_timeout may arrive from Robot as a string
        self._channel.settimeout(float(timeout))
        try:
            while True:
                matched = self._matched_prompt(buff, prompts)
                if matched is not None:
                    break
                resp = self._channel.recv(2048)
                if not resp:  # remote closed the connection
                    logger.write("SSH remote closed the connection (EOF).", 'WARN')
                    self._connection_lost = True
                    self.close()
                    break
                text = resp.decode('utf-8', errors='ignore')
                buff += text
                stamper.feed(text)
        except socket.timeout:
            # Prompt not seen in time; the connection itself may still be alive.
            pass
        except Exception as e:
            logger.write(f"Unexpected error while reading from SSH channel: {e}", 'ERROR')
            self.close()
        return matched, buff, stamper.render()

    def _send_raw(self, data, expect_prompt, timeout=5):
        # Send "data" exactly as given (no newline appended) and wait for prompt.
        self._channel.send(data)
        matched, buff, _ = self._read_until([expect_prompt], timeout)
        if matched is None:
            # Some sub-shells print their banner but no prompt until they get a
            # newline. "debug hal" is one: it answers "Trying to connect... /
            # Connected. / Press Ctrl-D to exit" and only shows "hal> " after Enter.
            logger.write(f"Prompt \"{expect_prompt}\" not seen yet, nudging with a newline", 'DEBUG')
            self._channel.send("\n")
            matched, more, _ = self._read_until([expect_prompt], timeout)
            buff += more
        if matched is None:
            robot.utils.asserts.fail(
                f"FAIL<>Timeout while waiting for prompt \"{expect_prompt}\" after sending {data!r}. "
                f"Received: {buff!r}")
        return buff

    def _drain_to_prompt(self, prompt, timeout=10):
        matched, buff, _ = self._read_until([prompt], timeout)
        if matched is None:
            robot.utils.asserts.fail(
                f"FAIL<>Can NOT find prompt \"{prompt}\" after login. Received: {buff!r}")
        return buff

    def _detect_level(self, timeout=3):
        prompt_to_level = {info["prompt"]: name for name, info in self.LEVELS.items()}
        self._channel.send("\n")
        matched, buff, _ = self._read_until(list(prompt_to_level.keys()), timeout)
        if matched is None:
            robot.utils.asserts.fail(f"FAIL<>Can NOT detect current level. Received: {buff!r}")
        return prompt_to_level[matched]

    def _goto_level(self, target):
        # FDX is the hub: leave the current level back to FDX, then enter target.
        current = self._detect_level()
        if current == target:
            logger.write(f"Already at level {target}", 'INFO')
            return

        fdx_prompt = self.LEVELS["FDX"]["prompt"]
        if current != "FDX":
            logger.write(f"Leaving level {current} back to FDX", 'INFO')
            self._send_raw(self.LEVELS[current]["exit"], fdx_prompt)
        if target != "FDX":
            logger.write(f"Entering level {target}", 'INFO')
            self._send_raw(self.LEVELS[target]["enter"], self.LEVELS[target]["prompt"])

    def _cmd_recv(self, cmd_str, prompt=None, resp_timeout=5):
        if self._channel is None:
            robot.utils.asserts.fail("FAIL<>SSH channel not established, call Connect first")
        if prompt is None:
            prompt = self.LEVELS[self._level]["prompt"]

        logger.write(f"\n\tSend \"{cmd_str}\"\n\tWait for prompt \"{prompt}\"\n\tTimeout : {resp_timeout}", 'DEBUG')
        self._connection_lost = False
        self._channel.send(cmd_str + "\n")
        matched, buff, stamped = self._read_until([prompt], resp_timeout)
        if matched is None:
            flag = f"FAIL<>Timeout reached while waiting for prompt: {prompt}"
            logger.write(flag, 'WARN')
        else:
            flag = f"PASS<>Get expected prompt: {prompt}"
        return flag, buff, stamped

    def _cmd_recv_with_retry(self, cmd_str, prompt=None, resp_timeout=5):
        """Run a command and run it again when the session died under it.

        The DUT drops the SSH session from time to time, and the command that
        was in flight when it happened never gets its answer. The session is
        rebuilt and the command is sent once more, which is what a person
        would do. The reboot is not repeated: a second "reset" would reboot
        the DUT twice.
        """
        flag, buff, stamped = self._cmd_recv(cmd_str, prompt, resp_timeout)
        if not self._connection_lost or cmd_str.strip() == "reset":
            return flag, buff, stamped
        logger.write(
            "the SSH session died during the command, the session is rebuilt"
            " and the command is sent again", 'WARN')
        self._ensure_connected()
        return self._cmd_recv(cmd_str, prompt, resp_timeout)

    def _save_log(self, log_name, log_content):
        # Append to the given log file, or to the main log when no name is given.
        # An empty name counts as no name, so a caller that has no log file of
        # its own can pass an empty string.
        # log_name may carry a sub-folder (e.g. "run_20261119_1532/fafe_0.log"),
        # the folder is created on demand.
        if not log_name:
            log_path = os.path.join(self._log_folder, self._main_log_name)
        else:
            log_path = os.path.join(self._log_folder, log_name)
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "ab") as file:
            file.write(log_content.encode('utf-8'))

    def _log_judgement(self, content):
        match_obj = re.search(r'PASS<>(.*)', content)
        if match_obj:
            return 1, match_obj.group(0)

        match_obj = re.search(r'FAIL<>(.*)', content)
        if match_obj:
            return 0, match_obj.group(0)

        return 0, "ERROR<>Can NOT find judgement content in log"


def _library_info(job):
    obj = ViperSSH
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

        print("Supported Interface Levels : ")
        for name, info in obj.LEVELS.items():
            print(f"\t{name:6s}: {info['prompt']!r}")

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
