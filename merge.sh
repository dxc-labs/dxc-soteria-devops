#!/usr/bin/env bash
#
# merge.sh - merges git master to production which triggers AWS CodePipeline
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
config="config/all.ini"

usage() { echo 2>&1 "Usage: $0 [-c config] component ..."; exit 1; }

while getopts 'c:' arg; do
    case "$arg" in
        c)
            config="$OPTARG"
            ;;
        [?])
            usage
            ;;
	esac
done
shift $((OPTIND-1))

if [ -z "$@" ]; then
    usage
fi

command -v git > /dev/null || { echo "git not found"; exit 1; }

# export config for use here too
export $(cat $config | xargs)

for component in "$@"
do
    # Merge master to production for specified component ($0)
    echo "Merging master to production in ${component} repository..."

    # Check the repo is up to date and doesn't need commit or stash
    if ! [[ `git --git-dir ../${component}/.git status --porcelain` ]]; then
        echo 2>&1 "Please commit or stash your changes first"; exit 1;
    fi

    # Checkout production branch.
    git --git-dir ../${component}/.git checkout production

    # Merge master into production
    git --git-dir ../${component}/.git merge master;

    # Push updates to mirror.
    git --git-dir ../${component}/.git push;

    # Checkout master branch
    git --git-dir ../${component}/.git checkout master
done
