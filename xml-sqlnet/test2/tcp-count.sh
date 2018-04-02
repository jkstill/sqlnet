#!/bin/bash

for f in *10046.trc
do
	echo "###  $f  ###"
	grep -cE  'bytes received|sent' $f 
done

