#!/usr/bin/env bash
#
# policy.sh - parses CloudFormation/CodePipeline's TemplateConfiguration to
#   extract and apply StackPolicy for each environment and component specified
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

# defaults
ConfigFile="config/all.ini"
Environment="dev"
DefaultRegion="us-east-1"
StackPolicy="config"

usage() { echo 2>&1 "Usage: $0 [-c config] [-e environment] -l -m -u <component>"; exit 1; }

while getopts 'c:e:lmr:u' arg; do
    case "$arg" in
        c)
            ConfigFile="$OPTARG"
            ;;
        e)
            EnvironmentOverride="$OPTARG" # comma separated variables e.g. dev,stg,prd
            ;;
        l)
            StackPolicy="lock"
            ;;
        m)
            StackPolicy="modify"
            ;;
        r)
            RegionOverfide-"$OPTARG"
            ;;
        u)
            StackPolicy="unlock"
            ;;
        [?])
            usage
            ;;
	esac
done
shift $((OPTIND-1))

# check for conflicts
if [ -n "$*" ] && ([ ${LockPolicy} ] || [ ${UnlockPolicy} ]); then
    echo "Specify either custom";
fi

# check aws-cli is available
command -v aws > /dev/null || echo 2>&1 "Cannot find 'aws' command"

# export config for use in this script as well as CloudFormation Templates
export $(cat $ConfigFile | xargs -L1)

# check for components override on command line
if [ -n "$*" ]; then Components="$*"; fi
if [ -n "$EnvironmentOverride" ]; then Environment="${EnvironmentOverride}"; fi
if [ -n "$RegionOverride" ]; then DefaultRegion="${RegionOverride}"; fi

# Setup infrastrucutre for each component (from a comma separated list with no spaces)
for Component in $(tr ',' '\n' <<< "${Components}")
do
#    for Environment in $(tr ',' '\n' <<< "${Environments}")
#    do
        echo "Setting stack policy for ${Component} in ${Environment}"
        # set stack policy
        case ${StackPolicy} in
            "config")         
                StackPolicyBody="$(python -c 'import json, os; d=json.loads(open("../'${Component}/'config/'${Environment}'.json").read()); print json.dumps(d["StackPolicy"], indent=2)')"
                ;;
            "lock")
                StackPolicyBody='{"Statement":[{"Effect":"Deny","Action":"Update:*","Principal":"*","Resource":"*"}]}'
            ;;
            "modify")
                StackPolicyBody='{"Statement":[{"Effect":"Allow","Action":"Update:Modify","Principal":"*","Resource":"*"}]}'
            ;;
            "unlock")
                StackPolicyBody='{"Statement":[{"Effect":"Allow","Action":"Update:*","Principal":"*","Resource":"*"}]}'
            ;;
        esac

        aws cloudformation set-stack-policy \
            --stack-name ${ProjectName}-${TenantName}-${Environment}-${Component} \
            --stack-policy-body "${StackPolicyBody}" \
            --region ${DefaultRegion} \
            --profile ${ProjectName}-${TenantName}-${Environment};

#    done
done
