// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import "./WETH9.invariants.t.sol";
import "./WETH9.sol";

contract CompiledWETH9Invariants is WETH9Invariants {
    function createWrappedNativeInstance() public virtual override {
        address wethTemplate = address(new WETH9());
        address wethAddress = vm.addr(0x12345678);
        bytes memory mainnetWethBytecode = wethTemplate.code;
        vm.etch(wethAddress, mainnetWethBytecode);
        weth = IWrappedNative(wethAddress);
    }
}