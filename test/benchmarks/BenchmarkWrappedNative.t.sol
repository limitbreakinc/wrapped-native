pragma solidity 0.8.25;

import "./BenchmarkBase.t.sol";
import "src/WrappedNative.sol";

contract BenchmarkWrappedNative is BenchmarkBase {
    function createWrappedNativeInstance() public virtual override {
        token = IWrappedNative(address(new WrappedNative()));
    }
}