#!/usr/bin/env python

import json
import os
import subprocess
import tempfile
import shutil
import boto3

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

def lambda_handler(event, context):
    print(f"Received Event: {event}")

    repository = ""
    # github webhook push event format
    repository = event["repository"]["name"]
    print(f"repository: {repository}")

    # securely create temp directory
    tmp = tempfile.mkdtemp()
    os.environ['HOME'] = tmp

    # Extract git config files (e.g. id_rsa, ssh_config, known_hosts) from SSM to temp dir
    parameters = {}
    for parameter in [ 'id_rsa', 'known_hosts', 'git_fetch_url_template', 'git_push_url_template' ]:
        with open(f"{tmp}/{parameter}", "w+", newline="\n") as f:
            ssm = boto3.client("ssm")
            ssm_parameter = "{}-{}".format(os.environ["AWS_LAMBDA_FUNCTION_NAME"], parameter)
            # print(f"ssm_parameter: {ssm_parameter}")
            parameters[parameter] = ssm.get_parameter(Name=ssm_parameter, WithDecryption=True)["Parameter"]["Value"]
            # print("{}: {}".format(parameter, parameters[parameter]))
            f.write(parameters[parameter] + "\n")
            os.chmod(f"{tmp}/{parameter}", 0o600)

    #fetch_url = os.environ["GIT_FETCH_URL_TEMPLATE"].format(repository)
    fetch_url = parameters["git_fetch_url_template"].format(repository)
    print(f"fetch_url: {fetch_url}")

    #push_url = os.environ["GIT_PUSH_URL_TEMPLATE"].format(repository)
    push_url = parameters["git_push_url_template"].format(repository)
    print(f"push_url: {push_url}")

    repo_dir = f"{tmp}/git-mirror"

    commands = [
        # -v -o StrictHostKeyChecking=no
        f"git config --global core.sshCommand 'ssh -o UserKnownHostsFile={tmp}/known_hosts -o IdentitiesOnly=yes -o BatchMode=yes -i {tmp}/id_rsa -F /dev/null'",
        f"git clone --mirror {fetch_url} {repo_dir}",
        f"git --git-dir {repo_dir} remote set-url --push origin {push_url}",
        #f"git --git-dir {repo_dir} fetch -p origin",
        f"git --git-dir {repo_dir} push --mirror",
    ]

    for command in commands:
        print(f"Running command: {command}")
        subprocess.run(["bash", "-c", command], text=True)

    # remove tmp directory
    shutil.rmtree(tmp)

    return gen_response(200, event)

# *#################################################

# Local testing

if __name__ == "__main__":
    event = {
        "body": {"repository": {"name": "devops", "owner": {"name": "soteria"},},},
    }

    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
    os.environ["AWS_DEFAULT_PROFILE"] = "soteria-dxc-dev"
    os.environ["AWS_LAMBDA_FUNCTION_NAME"] = "soteria-dxc-dev-devops-codecommit-sync"
    os.environ["GIT_FETCH_URL_TEMPLATE"] = "git@github.dxc.com:soteria/{}.git"
    os.environ["GIT_PUSH_URL_TEMPLATE"] = "ssh://APKA6NT273FISCHU4PPW@git-codecommit.us-east-1.amazonaws.com/v1/repos/soteria-{}"

    lambda_handler(event, None)

