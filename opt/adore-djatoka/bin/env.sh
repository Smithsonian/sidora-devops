#!/bin/sh
# setup environment variables for shell script
CURRENTDIR=$PWD
# Define DJATOKA_HOME dynamically

LAUNCHDIR=/opt/adore-djatoka-1.1/bin
#cd ..
DJATOKA_HOME=/opt/adore-djatoka-1.1
LIBPATH=$DJATOKA_HOME/lib

if [ `uname` = 'Linux' ] ; then
  if [ `uname -p` = "x86_64" ] ; then
    # Assume Linux AMD 64 has 64-bit Java
    PLATFORM="Linux-x86-64"
    LD_LIBRARY_PATH="$LIBPATH/$PLATFORM"
    export LD_LIBRARY_PATH
    KAKADU_LIBRARY_PATH="-DLD_LIBRARY_PATH=$LIBPATH/$PLATFORM"
  else
    # 32-bit Java
    PLATFORM="Linux-x86-32"
    LD_LIBRARY_PATH="$LIBPATH/$PLATFORM"
    export LD_LIBRARY_PATH
    KAKADU_LIBRARY_PATH="-DLD_LIBRARY_PATH=$LIBPATH/$PLATFORM"
  fi
elif [ `uname` = 'Darwin' ] ; then
  # Mac OS X
  PLATFORM="Mac-x86"
  export PATH="/System/Library/Frameworks/JavaVM.framework/Versions/1.5/Home/bin:$PATH"
  export DYLD_LIBRARY_PATH="$LIBPATH/$PLATFORM"
  KAKADU_LIBRARY_PATH="-DDYLD_LIBRARY_PATH=$LIBPATH/$PLATFORM"
elif [ `uname` = 'SunOS' ] ; then
  PLATFORM="Solaris-Sparc"
  LD_LIBRARY_PATH="$LIBPATH/$PLATFORM:$LD_LIBRARY_PATH"
  export LD_LIBRARY_PATH
else
  echo "djatoka env: Unsupported platform: `uname`"
  exit
fi

KAKADU_HOME=$DJATOKA_HOME/bin/$PLATFORM
#cd $LAUNCHDIR
#for line in `ls -1 $LIBPATH | grep '.jar'`
 # do
 # classpath="$classpath:$LIBPATH/$line"
#done
#go back to tomcat dir
#cd $CURRENTDIR
#DEBUG="-Xdebug -Xrunjdwp:transport=dt_socket,address=8000,server=y,suspend=n"
#CLASSPATH=.:../build/:$classpath
JAVA_OPTS="$JAVA_OPTS -Djava.awt.headless=true -Dkakadu.home=$KAKADU_HOME -Djava.library.path=$LIBPATH/$PLATFORM $KAKADU_LIBRARY_PATH"

# If a proxy server is used in your env... set the following
#proxySet=true
#proxyPort=8080
#proxyHost=proxyout.lanl.gov
#JAVA_OPTS="$JAVA_OPTS -DproxySet=$proxySet -DproxyPort=$proxyPort -DproxyHost=$proxyHost"
