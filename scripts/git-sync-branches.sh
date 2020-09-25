#!/usr/bin/env bash
pushd $1
echo '### push master ###'
git push
echo '### sandbox merge master ###'
git checkout sandbox
git merge master
git push
echo '### production merge master ###'
git checkout production
git merge master
git push
git checkout master
popd