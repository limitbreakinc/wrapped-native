pragma solidity 0.8.25;

import "./WNativeBase.t.sol";
import "../WETH9.sol";

contract WETH9Test is WNativeBaseTest {
    function createWrappedNativeInstance() public virtual override {
        weth = IWrappedNative(address(new WETH9()));
    }
}