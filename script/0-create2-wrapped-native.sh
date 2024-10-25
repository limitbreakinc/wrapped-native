#!/bin/bash
if [ -f .env.common ]
then
  export $(cat .env.common | xargs) 
else
    echo "Please set your .env.common file"
    exit 1
fi

echo "Bytecode: "
echo "----------"
echo $(forge inspect src/WrappedNative.sol:WrappedNative bytecode)
echo "----------"

constructorArgs=$(cast abi-encode "signature(address)" $ADDRESS_INFRASTRUCTURE_TAX)
constructorArgs=${constructorArgs:2}

wrappedNativeCode="$(forge inspect src/WrappedNative.sol:WrappedNative bytecode)"
wrappedNativeInitCode="$wrappedNativeCode$constructorArgs"

cast create2 --starts-with 000000 --case-sensitive --init-code $wrappedNativeInitCode
echo "create2 WrappedNative END"
echo "-------------------------------------"
echo ""