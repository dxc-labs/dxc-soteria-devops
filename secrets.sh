#!/usr/bin/env bash
#
# Copyright 2020 DXC Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# 1. secrets.sh -e dev -k # to generate ssh keys
# 2. "Upload SSH public key" id_rsa-dev.pub into AWS IAM "Manage my credentials" and GitHub
# 3. Get AWS "SSH key ID" (ie ssh username) and `secrets.sh -e dev -g -u <userid>` to save to file
# 4. `secrets.sh -e dev -a` to upload to SSM (but don't overwrite key!)
# 5. Send PR to improve this process

# defaults
export AWS_PAGER=""
ProjectName="soteria"
TenantName="dxc"
EnvironmentName="dev"
Profile="${ProjectName}-${TenantName}-${EnvironmentName}"
Region="us-east-1"
DefaultHosts="github.dxc.com git-codecommit.us-east-1.amazonaws.com"

usage() { echo 2>&1 "Usage: $0 -e [sbx|dev|stg|prd] [-r region] [-g] [-s] [-t tenant] <hosts>"; exit 1; }

while getopts 'ae:gkopr:st:u:xy' arg; do
    case "$arg" in
        a)
            KeyGen=true
            Scan=true
            Put=true
            GitUrlTemplates=true
            ;;
        e)
            EnvironmentName="$OPTARG"
            ;;
        g)
            GitUrlTemplates=true
            ;;
        k)
            KeyGen=true
            ;;
        o)
            ProjectName="$OPTARG"
            ;;
        p)
            Put=true
            ;;
        r)
            Region="$OPTARG"
            ;;        
        s)
            Scan=true
            ;;
        t)
            TenantName="$OPTARG"
            ;;
        u)
            User="$OPTARG"
            ;;
        x)
            eXterminate=true
            ;;
        y)
            Yes=true
            ;;
        [?])
            usage
            ;;
	esac
done
shift $((OPTIND-1))

# check aws-cli is available
command -v aws > /dev/null || echo 2>&1 "Cannot find 'aws' command"

# check for overrides on command line
if [ -n "$*" ]; then DefaultHosts="$*"; fi

# Set AWS configuration profile to use and test it
export Profile=${ProjectName}-${TenantName}-${EnvironmentName}
aws sts get-caller-identity --profile "${Profile}"

export AWS_LAMBDA_FUNCTION_NAME="${ProjectName}-${TenantName}-${EnvironmentName}-devops-codecommit-sync"

[ -z "${Get}" ] && [ -z "${Put}" ] && [ -z "${KeyGen}" ] && [ -z "${Scan}" ] \
    && [ -z "${eXterminate}" ] && [ -z "${User}" ] && [ -z "${GitUrlTemplates}" ] && \
    echo "${0}: Nothing to do. Flag [g]it templates, [k]eygen, [p]ut, [s]can, or [a]ll."

# ssh username from AWS IAM->My security credentials->AWS CodeCommit credentials
if [ $User ]; then
    echo -n "${User}" > user-${EnvironmentName}
    exit 0
else
    if [ -f "user-${EnvironmentName}" ]; then
        User=$(cat "user-${EnvironmentName}")
    fi
fi

# generate new key
if [ $KeyGen ]; then
    ssh-keygen -t rsa -b 2048 -f id_rsa -N '' -C ${ProjectName}-${TenantName}-${EnvironmentName}-devops -f id_rsa-${EnvironmentName}
fi

# scan
if [ $Scan ]; then
    ssh-keyscan -H $DefaultHosts | awk 1 > known_hosts-${EnvironmentName}
fi

# generate git fetch/push url templates
if [ $GitUrlTemplates ]; then
    echo -n "git@github.dxc.com:${ProjectName}/{}.git" > git_fetch_url_template-${EnvironmentName}
    echo -n "ssh://${User}@git-codecommit.${Region}.amazonaws.com/v1/repos/${ProjectName}-{}" > git_push_url_template-${EnvironmentName}
fi

if [ $Put ]; then
    # awk 1 adds trailing newline if required
    aws ssm put-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-id_rsa" --type "SecureString" --value "$(awk 1 id_rsa-${EnvironmentName})" --overwrite --tier Advanced
    aws ssm get-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-id_rsa"
    aws ssm put-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-git_fetch_url_template" --type "String" --value "$(cat git_fetch_url_template-${EnvironmentName})" --overwrite;
    aws ssm get-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-git_fetch_url_template"
    aws ssm put-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-git_push_url_template" --type "String" --value "$(cat git_push_url_template-${EnvironmentName})" --overwrite;
    aws ssm get-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-git_push_url_template"
    aws ssm put-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-known_hosts" --type "String" --value "$(cat known_hosts-${EnvironmentName})" --overwrite
    aws ssm get-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-known_hosts"
    #aws ssm put-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-ssh_config" --type "SecureString" --value "$(cat packages/codecommit-sync/ssh_config)" --overwrite
    #aws ssm get-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-ssh_config"
fi

if [ $eXterminate ]; then
    if [ $Yes ]; then
        aws ssm delete-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-id_rsa"
        aws ssm delete-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-user"
        aws ssm delete-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-known_hosts"
        #aws ssm delete-parameter --region $Region --profile ${Profile} --name "$AWS_LAMBDA_FUNCTION_NAME-ssh_config"
    fi
fi
