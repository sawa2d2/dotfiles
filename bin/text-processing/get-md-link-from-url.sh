#!/bin/bash

DIR=$(cd $(dirname $0); pwd)
URL=$1
TITLE=$(curl -sS $URL | sh $DIR/snippets/html-to-title.sh)
echo "[$TITLE]($URL)"
