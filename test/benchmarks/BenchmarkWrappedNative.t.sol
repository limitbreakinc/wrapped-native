pragma solidity 0.8.24;

import "./BenchmarkBase.t.sol";
import "src/WrappedNative.sol";
import "test/TestConstants.t.sol";

contract BenchmarkWrappedNative is BenchmarkBase {
    function createWrappedNativeInstance() public virtual override {
        token = IWrappedNative(address(new WrappedNative(ADDRESS_INFRASTRUCTURE_TAX)));
    }
}