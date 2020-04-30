#!/bin/bash

#get file 
wget --no-check-certificate https://raw.githubusercontent.com/caonimagfw/shadowsocks/master/shadowsocksR-debian p-linux64.tar.bz2
tar -xf p-linux64.tar.bz2
cd p-linux64
mv pypy2.7-v7.3.1-linux64 pypy
mv pypy /usr/local/

#create link 
ln -s  /usr/local/pypy/bin/pypy /usr/bin/pypy
