#!/bin/bash

if [ -z "$1" ]
  then
    echo -e "\r\nUsage:\r\nReleaseArchive <release tag> [destination]\r\nE.g. ReleaseArchive 0.1.6\r\nor\r\nReleaseArchive 0.1.6 /Users/abc/Downloads\r\n(Zip and Tar file will be output to ~\Desktop if not specified.)\r\n"
    exit
fi

libraryName=microsoft-authentication-library-for-objc
tag=$1
if [ -z "$2" ]; then destination=~/Desktop; else destination=$2; fi
releaseFolder=$libraryName-$tag

# archive the main project without submodule and uncompress it
git archive --prefix=$releaseFolder/ -o $destination/$mainProj.tar HEAD
tar -xf $destination/$mainProj.tar -C $destination/
rm $destination/$mainProj.tar

repoPath=`pwd`

# iterate the submodules, archive it and then uncompress it
git submodule foreach | while read omittedChars submodulePath; do
        # remove the first and last single quote from the path string
        submodulePath=${submodulePath#\'}
        submodulePath=${submodulePath%\'}
        
        cd $submodulePath
        git archive --prefix=$releaseFolder/$submodulePath/ HEAD > $destination/tmp.tar
        
        
        tar -xf $destination/tmp.tar -C $destination/
        rm $destination/tmp.tar
done

# create the target tar/zip file
cd $destination
tar -zcf ./$releaseFolder.tar.gz ./$releaseFolder
zip -r -q -X ./$releaseFolder.zip ./$releaseFolder
rm -R ./$releaseFolder

echo -e "\r\nDone!\r\n\r\n$releaseFolder.tar.gz\r\nand\r\n$releaseFolder.zip\r\nhave been created at $destination.\r\n"