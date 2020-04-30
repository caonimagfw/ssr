#!/bin/bash
#
yum install bzip2
#get file 
wget --no-check-certificate https://github.com/caonimagfw/ssr/raw/master/p-linux64.tar.bz2
tar -xf p-linux64.tar.bz2
rm -rf p-linux64.tar.bz2
mv pypy2.7-v7.3.1-linux64 pypy
mv pypy /usr/local/

#create link 
if [ ! -f "/usr/bin/pypy" ]; then
	ln -s  /usr/local/pypy/bin/pypy /usr/bin/pypy
fi