#!/bin/bash

function jwt_decode(){
    jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "$1"
}

jwt_decode $1