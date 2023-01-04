#!/bin/sh

cat "$@" | tr -d "\r" | tr -d "\n"
