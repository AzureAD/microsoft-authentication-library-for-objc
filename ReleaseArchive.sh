#!/bin/bash

if [ -z "$1" ]
  then
    echo -e "\n\rUsage: ReleaseArchive [release tag] \n\rE.g. ReleaseArchive 0.1.6\n\r"
    exit
fi

libraryName=microsoft-authentication-library-for-objc
tag=$1
releaseFolder=$libraryName-$tag

# archive the main project without submodule and uncompress it
git archive --prefix=$releaseFolder/ -o ~/Desktop/$mainProj.tar HEAD
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