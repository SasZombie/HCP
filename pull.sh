#/bin/bash

# Giving permissions to a script == modifing it for git
# Cool 
set -xe
rm startCluster.sh

git restore startCluster.sh
git pull