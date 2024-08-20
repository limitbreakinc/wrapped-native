// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "src/WrappedNative.sol";

contract DeployWrappedNative is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_KEY"));
        address deployed = address(new WrappedNative{salt: bytes32(vm.envUint("SALT_WRAPPED_NATIVE"))}());
        vm.stopBroadcast();

        console.log("WrappedNative: ", deployed);
        if (vm.envAddress("EXPECTED_ADDRESS_WRAPPED_NATIVE") != deployed) {
            revert("Unexpected deploy address");
        }
    }
}