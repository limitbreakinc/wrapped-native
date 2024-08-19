pragma solidity 0.8.25;

import "./WNativeBase.t.sol";
import "src/WrappedNative.sol";

contract WrappedNativeTest is WNativeBaseTest {
    function createWrappedNativeInstance() public virtual override {
        weth = IWrappedNative(address(new WrappedNative()));
    }
}