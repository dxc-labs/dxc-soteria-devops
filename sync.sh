#!/usr/bin/env bash
#
# mirror.sh - mirrors git repositories to local and on to AWS CodeCommit
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
Region="us-east-1"

usage() { echo 2>&1 "Usage: $0 [-c config] [-e environment] [-r region] <component>"; exit 1; }

while getopts 'c:e:r:' arg; do
    case "$arg" in
        c)
            ConfigFile="$OPTARG"
            ;;
        e)
            EnvironmentName="$OPTARG"
            ;;
        r)
            Region="$OPTARG"
            ;;
        [?])
            usage
            ;;
	esac
done
shift $((OPTIND-1))

# check git is installed
command -v git > /dev/null || { echo "git not found"; exit 1; }

# export config for use here too
export $(cat $ConfigFile | xargs)

# check for components override on command line
if [ -n "$*" ]; then Components="$*"; fi

# AWS configuration profile to use
export Profile=${ProjectName}-${TenantName}-${EnvironmentName}

# Setup repository for each component (from comma separated list, no spaces)
for Component in $(tr ',' '\n' <<< "${Components}");
do
    echo "Mirroring ${Component} repository..."

git_dir=git-mirrors/${Component}
set -e
    # First time only: Create a bare mirrored clone of the source repository
    # and set the push location to CodeCommit mirror.
    if test ! -d $git_dir;
    then
        mkdir -p $git_dir;
        git clone --mirror git@github.dxc.com:soteria/${Component}.git $git_dir;
    fi

    git --git-dir $git_dir remote add ${EnvironmentName} \
        codecommit::${Region}://${Profile}@${ProjectName}-${Component} || true

    # Fetch updates from origin.
    git --git-dir git-mirrors/${Component} fetch -p origin;

    # Push updates to mirror.
    git --git-dir git-mirrors/${Component} push --mirror ${EnvironmentName};
done
