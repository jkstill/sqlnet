#!/bin/bash

for f in *10046.trc
do
	echo "###  $f  ###"
	grep -E  'bytes received|sent' $f | sed -e s/'(overflow)'// |  awk '{ x = x + $1 } END{ print x}'
done

