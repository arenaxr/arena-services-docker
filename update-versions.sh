#!/bin/bash
# usage: ./collect_versions.sh [prod | dev]

prod_versions () {
    echo -e "\nThis will update the file named VERSION. Backup in VERSION.bak"

    cp VERSION VERSION.bak

    # get current docker services repo version and bump it
    version=$(git describe --tags --abbrev=0 2>/dev/null)
    version=${version:-v0.0.0}
    echo -e "\n\nCurrent arena service stack version=$version"
    nversion=v$(docker run --rm -it -v $PWD:/app -w /app treeder/bump --input $version)
    nversion=$version
    read -p "Enter the new arena service release version [$nversion]: " version
    ARENA_SERVICES_VERSION=${version:-$nversion}
    #sed -i "s/ARENA_SERVICES=.*/ARENA_SERVICES_VERSION=$ARENA_SERVICES_VERSION/" ./VERSION
    sed -i'' -e "s/ARENA_SERVICES=.*/ARENA_SERVICES_VERSION=$ARENA_SERVICES_VERSION/" ./VERSION

    echo -e "\n\nCollecting production versions...\n"
    submodules=$(git config --file .gitmodules --name-only --get-regexp path | cut -d. -f2)
    for sm in ${submodules}
    do
        cd $sm
        #git fetch --tags
        version=$(git describe --tags --abbrev=0)
        envvar=$(echo ${sm}_VERSION | tr '[:lower:]' '[:upper:]' | sed 's/-/_/g')
        cd ..
        sed -i'' -e "s/$envvar=.*/$envvar=$version/" ./VERSION
    done

    # fetch versions of repos that are not a submodule
    for i in ARENA_BROKER=https://github.com/SilverLineFramework/mosquitto-broker ARENA_FILESTORE=https://github.com/filebrowser/filebrowser.git ; do
        envvar=${i%\=*}_VERSION;
        repo=${i#*\=};
        version=$(git -c 'versionsort.suffix=-' \
            ls-remote --exit-code --refs --sort='version:refname' --tags $repo '*.*.*' \
            | tail -n 1 \
            | cut -d '/' -f 3)
        #echo $envvar=$version
        sed -i'' -e "s/$envvar=.*/$envvar=$version/" ./VERSION
    done

    # get utils version
    export $(grep '^ARENA_INIT_UTILS_VERSION=' init-utils/VERSION | xargs)
    ARENA_INIT_UTILS_VERSION=${ARENA_INIT_UTILS_VERSION:-latest:} # default to latest
    sed -i'' -e "s/ARENA_INIT_UTILS_VERSION=.*/ARENA_INIT_UTILS_VERSION=$ARENA_INIT_UTILS_VERSION/" ./VERSION

    docker pull arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION
    echo -e "\n### SPDX from template:"
    docker run --rm -v ${PWD}/conf-templates:/conf-templates -v ${PWD}/conf/arena-web-conf:/conf --env-file VERSION -e CREATE_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") arenaxrorg/arena-services-docker-init-utils:$ARENA_INIT_UTILS_VERSION sh -c  'envsubst < /conf-templates/versions.spdx.json.tmpl > /versions.spdx.json && pyspdxtools -i /versions.spdx.json -o /versions.spdx && cat /versions.spdx'

    echo -e "\n### New VERSION file definitions:"
    grep -v '^#' VERSION

    echo -e "\n\n### Want to commit and push the updated VERSION file ?"
    read -p "Continue? (y/N) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add VERSION
        git commit -m "ci: updated stack versions"
        git push
    fi

    echo -e -n "\n\nYou can manually push a new VERSION file, and create an arena services release $ARENA_SERVICES_VERSION from https://github.com/conix-center/arena-services-docker/releases\n\n"
}

dev_versions () {
    echo "Not implemented."
}

mode=${1:-prod}

case $mode in
    prod)
      prod_versions
      ;;
    staging | dev)
      dev_versions
      ;;
esac
