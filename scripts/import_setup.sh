#!/bin/bash
# usage: `cd scripts;bash mongoimport.sh`
# version number to import codes from, https://github.com/newsdev/odf/tree/master/competitions/OG2016/codes/?
_version="14.0"

# file will be downloaded into this folder from s3 bucket
_root="/tmp/${_version}"

_s3_location="s3://nyt-oly/OG2016/dev/tmp"

echo "Starting to read ${_root}/*.csv"
_dfiles="${_root}/*.csv"

for f in $_dfiles
do
	_basename=`basename "$f"`
	sed -i '' 's/Id,/id,/g' "${f}"
	# push file to s3 bucket
	aws s3 cp "${f}" "${_s3_location}/${_basename}"
done

echo "Files have been copied to s3"

echo "Run following commands on the pod you want to run import script on"

for f in $_dfiles
do
	_basename=`basename "$f"`
  #aws s3 cp "$f" "s3://nyt-oly/OG2016/dev/tmp/`basename "$f"`"
  echo "curl -o /tmp/14.0/$_basename http://s3.amazonaws.com/nyt-oly/OG2016/dev/tmp/$_basename"
done
