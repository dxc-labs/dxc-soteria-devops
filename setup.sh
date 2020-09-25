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

# defaults
ConfigFile="config/all.ini"
EnvironmentName="dev"
DefaultRegion="us-east-1"
GitHubOrgName="soteria"

usage() { echo 2>&1 "Usage: $0 -e [sbx|dev|stg|prd] [-c config] [-r region] <component>"; exit 1; }

while getopts 'ac:de:fkopr:styx' arg; do
    case "$arg" in
        a)
            Deploy=true
            PipelineTrigger=true
            SetStackPolicy=true
            EnableTerminationProtection=true
            ;;
        c)
            ConfigFile="$OPTARG"
            ;;
        d)
            Deploy=true
            ;;
        e)
            EnvironmentName="$OPTARG"
            ;;
        f) # configure AWS proFile
            ConfigAwsProfile=true
            ;;
        k)
            KillDevOpsStacks=true
            ;;
        o)  # cOntribute
            Contribute=true
            ;;
        p)
            PipelineTrigger=true
            ;;
        r)
            RegionOverride="$OPTARG"
            ;;
        s)
            SetStackPolicy=true
            ;;
        t)
            EnableTerminationProtection=true
            ;;
        y)
            Yes=true
            ;;
        x)
            KillApplicationStacks=true
            ;;
        [?])
            usage
            ;;
	esac
done
shift $((OPTIND-1))

# check aws-cli is available
command -v aws > /dev/null || echo 2>&1 "Cannot find 'aws' command"

# export config for use in this script as well as CloudFormation Templates
export $(cat $ConfigFile | xargs -L1)

# check for overrides on command line
if [ -n "$RegionOverride" ]; then DefaultRegion="${RegionOverride}"; fi
if [ -n "$*" ]; then Components="$*"; fi

# Set AWS configuration profile to use and test it
export Profile=${ProjectName}-${TenantName}-${EnvironmentName}

echo "Project Name is ${ProjectName}"
echo "Tenant Name is ${TenantName}"
echo "Environment Name is ${EnvironmentName}"
echo "Region is ${DefaultRegion}"

if [ "${ConfigAwsProfile}" ]; then
    aws configure --profile ${Profile}
fi

AWS_PAGER="" aws sts get-caller-identity --profile ${Profile}

# create global S3 bucket for packaging "genesis" cloudformation templates and running codepipelines
if [ "${Deploy}" ]; then
    AWS_PAGER="" aws s3 mb s3://${ProjectName}-${TenantName}-${EnvironmentName}-devops-codepipeline --region ${DefaultRegion} --profile ${Profile};
    AWS_PAGER="" aws s3 mb s3://${ProjectName}-${TenantName}-${EnvironmentName}-devops-cloudformation --region ${DefaultRegion} --profile ${Profile};

    if [ ${TenantName} != "global" ]; then
        AWS_PAGER="" aws s3 mb s3://${ProjectName}-${TenantName}-${EnvironmentName}-distribution-origin --profile ${Profile} --region ${DefaultRegion}
        AWS_PAGER="" aws s3 mb s3://${ProjectName}-${TenantName}-${EnvironmentName}-distribution-logs --profile ${Profile} --region ${DefaultRegion}

        AWS_PAGER="" aws s3 mb s3://${ProjectName}-${TenantName}-${EnvironmentName}-api-openapi --profile ${Profile} --region ${DefaultRegion}
     fi
fi

[ -z "${ConfigAwsProfile}" ] && [ -z "${Contribute}" ] && [ -z "${Deploy}" ] && [ -z "${SetStackPolicy}" ] && [ -z "${EnableTerminationProtection}" ] && [ -z "${PipelineTrigger}" ] \
    && [ -z "${KillDevOpsStacks}" ] && [ -z "${KillApplicationStacks}" ] && \
    echo "${0}: Nothing to do. Flag pro[F]ile, c[O]ntribute, [d]eploy, [p]ipeline, [s]et policy, [t]ermination protection, or [a]ll."

# Setup infrastrucutre for each component (from a comma separated list with no spaces)
for Component in $(tr ',' '\n' <<< "${Components}");
do

    # Developer environment setup to contribute
    if [ "${Contribute}" ];
    then
        echo "Clone ${Component} and create a remote branch ${TenantName}..."
        pushd ..
            git clone git@github.dxc.com:${GitHubOrgName}/${Component}
            pushd ${Component}
                git checkout -b ${TenantName}
                # git pull origin sandbox
                # git push
                cp ../devops/skeleton/config/${EnvironmentName}.json config/${ProjectName}-${TenantName}-${EnvironmentName}.json
                git add config/${ProjectName}-${TenantName}-${EnvironmentName}.json
                git commit -m "Add config files"
                git push -u origin ${TenantName}
            popd
        popd
    fi

    if [ "${Deploy}" ];
    then
        # create codecommit repository
        echo "Create component CodeCommit repository (error expected after first run)..."
        AWS_PAGER="" aws codecommit create-repository --repository-name ${ProjectName}-${Component} --region ${DefaultRegion} --profile ${Profile}
        # 2020-06-20 move bucket from stack to script for testing
        AWS_PAGER="" aws s3 mb s3://${ProjectName}-${TenantName}-${EnvironmentName}-${Component} --region ${DefaultRegion} --profile ${Profile};

        # deploy cloudformation
        AWS_PAGER="" aws cloudformation deploy \
            --stack-name ${ProjectName}-${TenantName}-${EnvironmentName}-${Component}-devops \
            --parameter-overrides ComponentName=${Component} EnvironmentName=${EnvironmentName} \
            $(cat $ConfigFile) \
            --template-file devops.yaml \
            --capabilities CAPABILITY_NAMED_IAM \
            --region ${DefaultRegion} \
            --profile ${Profile};
    fi

    if [ "${SetStackPolicy}" ];
    then
        # set stack policy
        AWS_PAGER="" aws cloudformation set-stack-policy \
            --stack-name ${ProjectName}-${TenantName}-${EnvironmentName}-${Component}-devops \
            --stack-policy-body file://config/setup-stack-policy.json \
            --region ${DefaultRegion} \
            --profile ${Profile};
    fi

    if [ "${EnableTerminationProtection}" ];
    then
    # enable termination protection
    AWS_PAGER="" aws cloudformation update-termination-protection \
        --enable-termination-protection \
        --stack-name ${ProjectName}-${TenantName}-${EnvironmentName}-${Component}-devops \
        --region ${DefaultRegion} \
        --profile ${Profile};
    fi

    if [ "${PipelineTrigger}" ];
    then
        # start pipeline execution
        AWS_PAGER="" aws codepipeline start-pipeline-execution \
            --name ${ProjectName}-${TenantName}-${EnvironmentName}-${Component} \
            --region ${DefaultRegion} \
            --profile ${Profile};
    fi

    if [ "${KillApplicationStacks}" ] || [ "${KillDevOpsStacks}" ];
    then
        if [ -z "${Yes}" ];
        then
            echo 2>&1 "Confirm kill with -y[es]"
            exit 1
        else
            if [ "${KillApplicationStacks}" ]; then
                # 2020-06-20 move bucket from stack to script for testing
                #AWS_PAGER="" aws s3 rm --recursive s3://${ProjectName}-${TenantName}-${EnvironmentName}-${Component} --region ${DefaultRegion} --profile ${Profile};
                AWS_PAGER="" aws s3 rb --force s3://${ProjectName}-${TenantName}-${EnvironmentName}-${Component} --region ${DefaultRegion} --profile ${Profile};
            fi

            # enable termination protection
            AWS_PAGER="" aws cloudformation update-termination-protection \
                --no-enable-termination-protection \
                --stack-name ${ProjectName}-${TenantName}-${EnvironmentName}-${Component}${KillDevOpsStacks:+-devops} \
                --region ${DefaultRegion} \
                --profile ${Profile};

            # start pipeline execution
            AWS_PAGER="" aws cloudformation delete-stack \
                --stack-name ${ProjectName}-${TenantName}-${EnvironmentName}-${Component}${KillDevOpsStacks:+-devops} \
                --region ${DefaultRegion} \
                --profile ${Profile};

        fi
    fi

done
