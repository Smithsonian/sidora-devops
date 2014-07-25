# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/bin
export PATH

export FEDORA_HOME=/usr/local/fedora
export CATALINA_HOME=/usr/local/fedora/tomcat
#export JAVA_OPTS="-Xms8192m -Xmx32768m -XX:MaxPermSize=512m -Djavax.net.ssl.trustStore=/usr/local/fedora/server/truststore -Djavax.net.ssl.trustStorePassword=tomcat"
export JAVA_OPTS="-Xms1024m -Xmx6144m -XX:MaxPermSize=256m" 
export DBXML_HOME=/usr/local/dbxml-2.5.13
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${DBXML_HOME}/lib

# Functions
mecp () { scp $@ ${SSH_CLIENT%% *}:~/Downloads; }
