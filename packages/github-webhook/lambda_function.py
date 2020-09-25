#!/usr/bin/env python

import boto3
import json
import os

#############################################


def gen_response(status_code, body=None):
    if body:
        body = json.dumps(body)
    else:
        body = ""
    response = {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": body,
        "isBase64Encoded": False,
    }
    return response


#############################################


def lambda_handler(event, context):
    print(f"Received Event: {event}")

    body = event.get("body", None)
    if not isinstance(body, dict):
        try:
            body = json.loads(body)
        except AttributeError as err:
            response = f"bad input, expected dict -> {err}"
            return gen_response(400, response)
        except Exception as err:
            response = f"unknown error -> {err}"
            return gen_response(500, response)

    client = boto3.client("lambda")
    response = client.invoke(
        FunctionName=os.environ["ASYNC_FUNCTION_NAME"],
        InvocationType="Event",
        Payload=bytes(json.dumps(body), "utf-8"),
    )

    return gen_response(201)
