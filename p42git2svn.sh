#!/bin/sh

# Set these before you start
# export P4PORT=myperforceserver:1666
# export P4USER=myusername
# export P4PASSWD=mypassword

# Source Perforce depot path (without @all)
P4PATH="$1"

# Destination SVN url (without trunk, we create that)
SVNPATH="$2"

PROJECT=`basename "${SVNPATH}"`

# git p4 clone "${P4PATH}@all" "${PROJECT}.gitp4"

mkdir "${PROJECT}.patches"
cd "${PROJECT}.gitp4"
git format-patch --root HEAD -o "../${PROJECT}.patches"
cd ..

svn mkdir --parents "${SVNPATH}/"{trunk,branches,tags} \
          -m "Initial repository layout."
git svn clone "${SVNPATH}/trunk" "${PROJECT}.gitsvn"

cd "${PROJECT}.gitsvn"
git am "../${PROJECT}.patches/"*
git svn dcommit --add-author-from
cd ..
