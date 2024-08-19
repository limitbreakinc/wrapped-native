// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "src/IWrappedNative.sol";

import "./handlers/Handler.sol";

abstract contract WETH9Replay is Test {
    IWrappedNative public weth;
    Handler public handler;

    function createWrappedNativeInstance() public virtual;

    function setUp() public {
        createWrappedNativeInstance();
        handler = new Handler(weth);
        console.log("Handler: ", address(handler));
        console.log("Weth: ", address(weth));
    }

    function test_sequence() public {
        vm.prank(address(0xB5c512488C5BeeF74Af78ffd087b034B724e9D4C));
        handler.sendFallback(2430412327);

        vm.prank(address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f));
        handler.deposit(103396883668530870293050071);

        uint256 sumOfBalances = handler.reduceActors(0, this.accumulateBalance);

        console.log(address(weth).balance);
        console.log(sumOfBalances);

        /*
        uint256 sumOfBalances = handler.reduceActors(0, this.accumulateBalance);
        assertEq(address(weth).balance - handler.ghost_forcePushSum(), sumOfBalances);
        */
    }

    function accumulateBalance(uint256 balance, address caller) external view returns (uint256) {
        console.log("reduceActors balance", weth.balanceOf(caller));
        console.log(caller);
        return balance + weth.balanceOf(caller);
    }

    
}