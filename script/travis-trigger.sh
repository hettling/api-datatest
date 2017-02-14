#!/bin/sh

org="hettling"
repo="api-datatest"
branch="master"
message="triggered from spreadsheet change"
body="{
             \"request\": {
               \"branch\": \"${branch}\",
               \"message\": \"${message}\"
              }
           }"

curl -s -X POST \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -H "Travis-API-Version: 3" \
     -H "Authorization: token $TRAVIS_TOKEN" \
     -d "$body" \
     "https://api.travis-ci.org/repo/${org}%2F${repo}/requests"
