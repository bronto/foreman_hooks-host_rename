#!/bin/sh
#echo renaming $1 to $2
if [ $1 != 'foo.example.com' ] ; then
  echo "fail: $1 != foo.example.com"
  exit 1
fi

if [ $2 != 'bar.example.com' ] ; then
  echo "fail: $2 != bar.example.com"
  exit 1
fi

exit 0
