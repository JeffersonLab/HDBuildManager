#!/bin/csh
wget https://julialang.s3.amazonaws.com/bin/linux/x64/0.3/julia-0.3.9-linux-x86_64.tar.gz
mkdir ../julia-0.3.9 
tar -xzf julia-0.3.9-linux-x86_64.tar.gz -C ../julia-0.3.9 --strip-components=1
rm julia-0.3.9-linux-x86_64.tar.gz
setenv PATH `pwd`/../julia-0.3.9/bin:$PATH
