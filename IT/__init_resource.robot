*** Settings ***
# @author: Ian Yin
# @version: V1.0.0
# @updated: 2026-11-19
# @comment: what every IT suite imports
# Global Variables
Resource    ../variables/env_variables.robot
Resource    ../variables/dut_variables.robot
Resource    ../variables/fw_variables.robot
# Common Keywords
Resource    ../resource/Common/IT_Common.resource
# Custom General Library
Library    ../lib/AutomationFlow.py
# The IT suites drive the DUT over its own management SSH. Two sessions are
# open, one per shell: the clish prompt (FDX) and the linux shell (ROOT).
# The gNMI and gRPC sessions run on the DUT as well. The three libraries are
# imported by IT_Common.resource, which this file imports, so the aliases
# SSH_IT, SSH_IT_ROOT and GNMI_IT are in scope here.
