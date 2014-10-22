#!/bin/sh
#echo renaming $1 to $2
test $1 = 'foo.example.com' || exit 1
test $2 = 'bar.example.com' || exit 1
exit 0
