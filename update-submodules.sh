#!/bin/bash

submodules=$(git config --file .gitmodules --get-regexp path | cut -d. -f2)

for sm in ${submodules}
do
	echo $sm
    cd $sm
	git fetch --tags
	version=$(git describe --tags --abbrev=0)
	git checkout $version
    cd ..
done

echo -e "\n### Want to commit and push the update to the submodules ?"
read -p "Continue? (y/N) " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
	for s in ${submodules}
	do
		repo=`echo $s | cut -d':' -f1`
	  git add $repo
	done

	# commit the change in arena-services-docker repo
	git commit -m "Updated submodules to latest commit"
	git push
fi
