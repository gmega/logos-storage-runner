#!/usr/bin/env bash

mkdir ./testfiles

dd if=/dev/urandom of=testfiles/testfile1 bs=1M count=50
dd if=/dev/urandom of=testfiles/testfile2 bs=1M count=50