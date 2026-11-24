# @author: Jet Qian
# @version: V1.0.1
# @updated: 2026-11-19
# @comment: the management endpoints of the DUT that the IT suites drive

*** Variables ***
# Template. Copy this file to variables/ and fill in your own testbed values.

# === IT Automation (DZ300-1757) ===
# The IT suites drive the DUT over its management SSH and run gnmic / grpcurl
# ON the DUT itself, against the loopback address. The DUT carries both
# binaries (/usr/bin/gnmic, /usr/bin/grpcurl), so no separate gNMI client host
# is needed and the eAMP IPv6 never has to be resolved.
#
# The management address is a property of the unit, not of the firmware.
&{SSH_DUT_IT}    name=DUT_IT_SSH    host=<dut_it_host>    port=22    username=<your_username>    password=<your_password>
...    timeout=10    prompt=>
# The gNMI server listens on the DUT's own loopback, so the target address is
# 127.0.0.1. gnmic runs on the DUT as well, because ViperGnmi uses a non
# interactive exec channel: the command lands on the SSH host, which is the DUT.
# timeout is this target's default gNMI timeout, 0 means gnmic keeps its own
# default of 10s
&{GNMI_DUT_IT}    name=DUT_IT_GNMI    host=127.0.0.1    port=9339    insecure=True    timeout=0
# The gRPC (gnoi) server, same loopback idea, one port above the gNMI one.
&{GRPC_DUT_IT}    name=DUT_IT_GRPC    host=127.0.0.1    port=9338
# The proto files the grpcurl calls import from.
&{GRPC_PROTO_PATH}    name=GRPC_PROTO    path=/etc/amp/proto/
# The serial number of the bench DUT, used by the sanity checks that compare
# the DUT against itself.
${DUT_IT_SERIAL}    <dut_it_serial>
# The address of the cable modem of the bench, the DUT asks it over SNMP for
# its DOCSIS operational status.
${CM_SNMP_ADDRESS}    <cm_snmp_address>
