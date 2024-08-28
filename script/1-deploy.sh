#!/usr/bin/env bash

if [ -f .env.secrets ]
then
  export $(cat .env.secrets | xargs) 
else
    echo "Please set your .env.secrets file"
    exit 1
fi

if [ -f .env.common ]
then
  export $(cat .env.common | xargs) 
else
    echo "Please set your .env.common file"
    exit 1
fi

# Initialize variables
GAS_PRICE=""
PRIORITY_GAS_PRICE=""
RESUME=""

# Function to display usage
usage() {
    echo "Usage: $0 --gas-price <gas price> --priority-gas-price <priority gas price>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --gas-price) GAS_PRICE=$(($2 * 1000000000)); shift ;;
        --priority-gas-price) PRIORITY_GAS_PRICE=$(($2 * 1000000000)); shift ;;
        --resume) RESUME="--resume" ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$GAS_PRICE" ] || [ -z "$PRIORITY_GAS_PRICE" ]; then
    usage
fi

echo ""
echo "============= DEPLOYING WRAPPED NATIVE ============="

echo "Gas Price (wei): $GAS_PRICE"
echo "Priority Gas Price (wei): $PRIORITY_GAS_PRICE"
echo "RPC URL: $RPC_URL"
echo "SALT_WRAPPED_NATIVE: $SALT_WRAPPED_NATIVE"
echo "EXPECTED_ADDRESS_WRAPPED_NATIVE: $EXPECTED_ADDRESS_WRAPPED_NATIVE"
read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

# Identify if any prerequisites are missing:
# 1. Deterministic Deploy Proxy Address (0x4e59b44847b379578588920cA78FbF26c0B4956C)
DETERMINISTIC_DEPLOY_PROXY_BYTECODE=$(cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url $RPC_URL)
if [ "$DETERMINISTIC_DEPLOY_PROXY_BYTECODE" = "0x" ]; then
    # Send .01 ETH to deterministic deploy proxy deployer
    cast send 0x3fAB184622Dc19b6109349B94811493BF2a45362 --value 10000000000000000 --gas-price $GAS_PRICE --priority-gas-price $PRIORITY_GAS_PRICE --rpc-url $RPC_URL --private-key $DEPLOYER_KEY

    # Create Deterministic Deploy Proxy
    cast publish --rpc-url ${RPC_URL} 0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222
fi

forge script script/DeployWrappedNative.s.sol:DeployWrappedNative \
  --gas-price $GAS_PRICE \
  --priority-gas-price $PRIORITY_GAS_PRICE \
  --rpc-url $RPC_URL \
  --broadcast \
  --optimizer-runs 1000000 \
  --verify $RESUME