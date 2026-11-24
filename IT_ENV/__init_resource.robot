*** Settings ***
# @author: Ian Yin
# @version: V1.0.0
# @updated: 2026-11-19
# @comment: what every environment check imports
# The environment check of the LE IT test template. It is not a sheet of the
# template, it is the check that the bench is ready before the campaign
# starts, so it sits beside IT/ and not inside it: that way the campaign
# runs it once, before the test items.
Resource    ../IT/__init_resource.robot
