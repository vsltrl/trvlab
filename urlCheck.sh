#!/bin/bash

if [ -z "$1" ]; then
    echo "input url"
    exit 1
fi

response=$(curl -s -o /dev/null -w "%{http_code}" "$1")

if [ "$response" -eq 200 ]; then
    echo "success"
else
    echo "failure"
fi
