#!/bin/bash

url=$1

response_code=$(curl -s -o /dev/null -w "%{http_code}" $url)

if [ "$response_code" -eq 200 ]; then
    echo "success"
else
    echo "failure"
fi
