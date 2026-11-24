"""Read the JSON documents out of a gRPC answer.

grpcurl prints one JSON document per message of a call. A call that answers
with a single message prints one document, a streaming call prints one per
message, e.g. the progress of the calibration stages of StartCalibration and
the failure at the end of it.

The module is a plain python module, not a Robot library, but it is imported
by IT_Common.resource as a library, so its functions are keywords.
"""

import json
import math


def parse_documents(text):
    """The JSON documents of an answer, in the order they came in.

    An answer that holds no document at all gives an empty list. An answer
    that is not JSON raises an AssertionError, because a caller wants to know
    that the DUT did not answer with JSON at all.
    """
    decoder = json.JSONDecoder()
    documents = []
    index = 0
    text = text.strip()
    while index < len(text):
        while index < len(text) and text[index].isspace():
            index += 1
        if index >= len(text):
            break
        try:
            document, index = decoder.raw_decode(text, index)
        except ValueError as error:
            raise AssertionError(
                "The answer of the gRPC call is not JSON: %s\n%s" % (error, text))
        documents.append(document)
    return documents


_CALIBRATION_STAGES = ("STAGE_DS1", "STAGE_DS2", "STAGE_DS3", "STAGE_US1")


def _check_manual_adjustments(adjustments):
    if not isinstance(adjustments, list) or not adjustments:
        raise AssertionError("Manual adjustment must contain adjustment details")
    for item in adjustments:
        if not isinstance(item, dict) or item.get("type") not in ("DS_IN_EQ", "DS_IN_ATT"):
            raise AssertionError("Invalid manual adjustment: %s" % item)
        value = item.get("adjustmentValue", 0)
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise AssertionError("Invalid manual adjustment value: %s" % item)


def check_calibration_stream(documents, mode):
    """Validate stage order and terminal response of a calibration stream."""
    if mode not in ("AUTO", "SEMI_AUTO", "MANUAL"):
        raise AssertionError("Invalid calibration mode: %s" % mode)
    if not isinstance(documents, list) or not documents:
        raise AssertionError("Calibration stream is empty")
    stages = []
    adjusted = False
    succeeded = False
    for index, event in enumerate(documents):
        if not isinstance(event, dict) or len(event) != 1:
            raise AssertionError("Invalid calibration event: %s" % event)
        kind, payload = next(iter(event.items()))
        if not isinstance(payload, dict):
            raise AssertionError("Invalid calibration event payload: %s" % event)
        if kind == "failure":
            raise AssertionError("Calibration failed: %s" % payload)
        if kind == "progress":
            if adjusted or succeeded:
                raise AssertionError("Progress after calibration finished: %s" % event)
            status = payload.get("status", "")
            if not isinstance(status, str) or not status.startswith("CALIBRATION_STAGE_"):
                raise AssertionError("Invalid calibration progress: %s" % event)
            stage = "STAGE_" + status[len("CALIBRATION_STAGE_"):]
            if stage not in _CALIBRATION_STAGES:
                raise AssertionError("Unknown calibration stage: %s" % stage)
            if not stages or stages[-1] != stage:
                stages.append(stage)
                expected = _CALIBRATION_STAGES[:len(stages)]
                if tuple(stages) != expected or (mode == "MANUAL" and len(stages) > 1):
                    raise AssertionError("Unexpected calibration stage order: %s" % stages)
        elif kind == "adjustment":
            if mode != "SEMI_AUTO" or adjusted or succeeded or not stages:
                raise AssertionError("Unexpected calibration adjustment: %s" % event)
            if payload.get("stage") != stages[-1]:
                raise AssertionError("Adjustment does not match current stage: %s" % event)
            _check_manual_adjustments(payload.get("manualAdjustments"))
            adjusted = True
        elif kind == "success":
            if succeeded or index != len(documents) - 1 or payload.get("status") != "SUCCESS":
                raise AssertionError("Invalid calibration success: %s" % event)
            succeeded = True
        else:
            raise AssertionError("Unknown calibration event: %s" % event)
    if not stages:
        raise AssertionError("Calibration stream has no stage progress")
    if adjusted:
        return "MANUAL_ADJUSTMENT"
    expected = _CALIBRATION_STAGES[:1] if mode == "MANUAL" else _CALIBRATION_STAGES
    if tuple(stages) != expected or not succeeded:
        raise AssertionError("Calibration did not complete successfully: %s" % documents)
    return "SUCCESS"


def check_calibration_status(response):
    """Validate the status response, including optional proto3 adjustments."""
    if not isinstance(response, dict) or response.get("failure") is not None:
        raise AssertionError("Calibration status failed: %s" % response)
    success = response.get("success")
    if not isinstance(success, dict) or success.get("status") != "SUCCESS":
        raise AssertionError("Calibration status did not succeed: %s" % response)
    if "isCalibrating" in response and not isinstance(response["isCalibrating"], bool):
        raise AssertionError("Invalid isCalibrating: %s" % response)
    infos = response.get("stageInfos")
    if not isinstance(infos, list):
        raise AssertionError("Missing calibration stageInfos: %s" % response)
    stages = []
    for info in infos:
        if not isinstance(info, dict):
            raise AssertionError("Invalid calibration stage info: %s" % info)
        # Proto3 JSON omits the default UNKNOWN enum value.
        stage, status = info.get("stage"), info.get("status", "UNKNOWN")
        if stage not in _CALIBRATION_STAGES or status not in ("UNKNOWN", "UNALIGNED", "IN_PROGRESS", "ALIGNED", "FAILED"):
            raise AssertionError("Invalid calibration stage or status: %s" % info)
        if "manualAdjustments" in info:
            adjustments = info["manualAdjustments"]
            if not isinstance(adjustments, list):
                raise AssertionError("Invalid manual adjustments: %s" % info)
            if adjustments:
                _check_manual_adjustments(adjustments)
        stages.append(stage)
    if len(stages) != len(_CALIBRATION_STAGES) or set(stages) != set(_CALIBRATION_STAGES):
        raise AssertionError("Expected exactly four calibration stages: %s" % stages)
    return response
