#!/usr/bin/env bash
for i in $(basename $(find . -name [a-z]* -type d -maxdepth 1)); do pushd $i; echo $i; git checkout production; git merge master; git push; git checkout master; popd; done

