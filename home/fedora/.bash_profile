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

#fedora_export() {
#    /usr/local/fedora_test/client/bin/fedora-export.sh localhost:8080 fedoraAdmin f3d0r@@dmin $1 info:fedora/fedora-system:FOXML-1.1 archive . http fedora
#}

#fedora_purge() {
#   /usr/local/fedora_test/client/bin/fedora-purge.sh localhost:8080 fedoraAdmin f3d0r@@dmin $1 http 'removed object'
#}

# Functions
mecp () { scp $@ ${SSH_CLIENT%% *}:~/Downloads; }
