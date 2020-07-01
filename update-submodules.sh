#!/bin/bash

git submodule update --init --recursive 

# commit the change in arena-services-docker repo 
git add ARENA-core 
git commit -m "Update submodules to latest commit in master"
git push
