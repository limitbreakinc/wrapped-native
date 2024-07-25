pragma solidity 0.8.17;

import "./BenchmarkBase.t.sol";
import "../WETH9.sol";

contract BenchmarkCompiledWETH9 is BenchmarkBase {
    function createWrappedNativeInstance() public virtual override {
        token = IWrappedNative(address(new WETH9()));
    }
}