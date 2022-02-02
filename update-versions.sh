#!/bin/bash
# usage: ./collect_versions.sh [prod | staging | dev]

prod_versions () {  
    echo -e "\nThis will update version.env."
    read -p "Continue? (y/N) " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then  
        exit 1
    fi
    echo -e "\n\nCollecting production versions"
    submodules=$(git config --file .gitmodules --name-only --get-regexp path | cut -d. -f2)
    for sm in ${submodules}
    do
        cd $sm
        #git fetch --tags
        version=$(git describe --tags --abbrev=0)
        envvar=${sm^^}
        envvar=${envvar//-/_}
        cd ..
        #echo $envvar=$version
        sed -i "s/$envvar=.*/$envvar=$version/" ./version.env 
    done

    # fetch versions of repos that are not a submodule
    for i in ARENA_BROKER=https://github.com/conix-center/ARENA-broker.git ARENA_FILESTORE=https://github.com/filebrowser/filebrowser.git ; do 
        envvar=${i%\=*};
        repo=${i#*\=};
        version=$(git -c 'versionsort.suffix=-' \
            ls-remote --exit-code --refs --sort='version:refname' --tags $repo '*.*.*' \
            | tail --lines=1 \
            | cut --delimiter='/' --fields=3)
        #echo $envvar=$version
        sed -i "s/$envvar=.*/$envvar=$version/" ./version.env 
    done

    # confirm utils version
    export $(grep '^ARENA_INIT_UTILS=' version.env | xargs)
    echo "Current arena init utils version=$ARENA_INIT_UTILS" 
    read -p "Enter the arena init utils version [$ARENA_INIT_UTILS]: " version
    ARENA_INIT_UTILS_VERSION=${version:-$ARENA_INIT_UTILS}
    sed -i "s/ARENA_INIT_UTILS=.*/ARENA_INIT_UTILS=$ARENA_INIT_UTILS_VERSION/" ./version.env 

    # get current docker services repo version and bump it
    version=$(git describe --tags --abbrev=0 2>/dev/null)
    version=${version:-v0.0.0}
    echo "Current arena service stack version=$version"
    nversion=$(docker run --rm -it -v $PWD:/app -w /app treeder/bump --input $version)
    read -p "Enter the release version [$nversion]: " version
    ARENA_SERVICES_VERSION=${version:-$nversion}
    sed -i "s/ARENA_SERVICES=.*/ARENA_SERVICES=$ARENA_SERVICES_VERSION/" ./version.env 

    echo -e "\n### Versions (in version.env) updated to:"
    docker run --rm -v ${PWD}/conf-templates:/conf-templates -v ${PWD}/conf/arena-web-conf:/conf --env-file version.env conixcenter/arena-services-docker-init-utils sh -c 'envsubst < /conf-templates/versions.txt.tmpl'

    echo -e "\n\n### Want to commit and push the updated version.env ?"
    read -p "Continue? (y/N) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add versions.env
        git commit -m "ci: updated stack versions"
        git push
    fi

    echo -e -n "\n\nYou can manually push a new version of versions.env, and create a release on https://github.com/conix-center/arena-services-docker/releases"
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