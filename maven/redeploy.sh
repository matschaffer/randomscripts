#!/bin/sh

JAR="http://maven/content/groups/master/$1"
POM="`dirname $JAR`/`basename "$JAR" .jar`.pom"

curl -O "$JAR"
curl -O "$POM"

mvn deploy:deploy-file -Durl=scp://cim-trac.comcastonline.com/opt/csw/apache2/share/htdocs/http/godzilla/maven/repo/snapshots \
                       -DrepositoryId=comcast-snapshot-repo \
                       -Dfile="`basename $JAR`" -DpomFile="`basename $POM`"