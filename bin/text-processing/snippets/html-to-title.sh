#!/bin/sh
cat $@ | tr -d "\r" | tr -d "\n" | grep -o '<title>.*</title>' | sed 's#<title>\(.*\)</title>#\1#'
