#!/bin/bash
echo "Bytecode: "
echo "----------"
echo $(forge inspect src/WrappedNative.sol:WrappedNative bytecode)
echo "----------"

cast create2 --starts-with 000000 --case-sensitive --init-code $(forge inspect src/WrappedNative.sol:WrappedNative bytecode)