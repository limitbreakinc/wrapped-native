pragma solidity 0.8.24;

import "./WNativeBase.t.sol";
import "src/WrappedNative.sol";
import "test/TestConstants.t.sol";

contract WrappedNativeTest is WNativeBaseTest {
    function createWrappedNativeInstance() public virtual override {
        weth = IWrappedNative(address(new WrappedNative(ADDRESS_INFRASTRUCTURE_TAX)));
    }
}