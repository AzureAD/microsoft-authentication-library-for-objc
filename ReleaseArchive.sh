#!/bin/bash

if [ -z "$1" ]
  then
    echo -e "\n\rUsage: ReleaseArchive [release tag] [commit number] \n\rE.g. ReleaseArchive 0.1.6 a44af92b4b255981161eacc304417368 \n\ror \n\rReleaseArchive 0.1.6 (if release tag has been created in Github)\n\r"
    exit
fi

libraryName=microsoft-authentication-library-for-objc
tag=$1
if [ -z "$2" ]; then commit=tag; else commit=$2; fi
releaseFolder=$libraryName-$tag

# archive the main project without submodule and uncompress it
git archive --prefix=$releaseFolder/ -o ~/Desktop/$mainProj.tar $commit
tar -xf ~/Desktop/$mainProj.tar -C ~/Desktop/
rm ~/Desktop/$mainProj.tar

repoPath=`pwd`

# iterate the submodules, archive it and then uncompress it
git submodule foreach | while read omittedChars submodulePath; do
        # remove the first and last single quote from the path string
        submodulePath=${submodulePath#\'}
        submodulePath=${submodulePath%\'}
        
        cd $submodulePath
        git archive --prefix=$releaseFolder/$submodulePath/ HEAD > ~/Desktop/tmp.tar
        
        
        tar -xf ~/Desktop/tmp.tar -C ~/Desktop/
        rm ~/Desktop/tmp.tar
done

# create the target tar/zip file
cd ~/Desktop
tar -cf ./$releaseFolder.tar ./$releaseFolder
zip -r -X ./$releaseFolder.zip ./$releaseFolder
rm -R ./$releaseFolder

echo "Release tar/zip have been created and put at ~/Desktop"