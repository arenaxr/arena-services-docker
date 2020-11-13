#!/bin/bash

submodules=( "ARENA-core:master" "ARENA-auth:master" "arena-account:main" "arena-persist:master" "arts:master" "arena-runtime-simulated:master")

for s in "${submodules[@]}"
do
	echo $s
	repo=`echo $s | cut -d':' -f1`
	branch=`echo $s | cut -d':' -f2`
  cd $repo
  git checkout $branch
  git pull
  cd ..
  git add $repo
done

# commit the change in arena-services-docker repo
git commit -m "Updated submodules to latest commit"
git push
