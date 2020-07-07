#!/bin/bash

cd ARENA-core
git checkout master
git pull

cd ..

cd arena-persist
git checkout master
git pull

cd ..

# commit the change in arena-services-docker repo 
git add ARENA-core 
git commit -m "Update submodules to latest commit in master"
git push
