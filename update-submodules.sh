#!/bin/bash

submodules=( "ARENA-core" "arena-persist" "arts" "arena-runtime-simulated")

for s in "${submodules[@]}"
do
	echo $s
  cd $s
  git checkout master
  git pull
  cd ..
  git add $s
done

# commit the change in arena-services-docker repo
git commit -m "Updated submodules to latest commit"
git push
