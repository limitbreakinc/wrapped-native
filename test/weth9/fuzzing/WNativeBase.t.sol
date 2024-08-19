// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "src/IWrappedNative.sol";

abstract contract WNativeBaseTest is Test {
    event  Approval(address indexed src, address indexed guy, uint256 wad);
    event  Transfer(address indexed src, address indexed dst, uint256 wad);
    event  Deposit(address indexed dst, uint256 wad);
    event  Withdrawal(address indexed src, uint256 wad);

    IWrappedNative public weth;

    function createWrappedNativeInstance() public virtual;

    function setUp() public {
        createWrappedNativeInstance();
    }

    function testDeposit(uint256 amount) public {
        address user = vm.addr(1);
        vm.deal(user, amount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user, amount);
        vm.startPrank(user);
        weth.deposit{value: amount}();
        assertEq(weth.balanceOf(user), amount);
        assertEq(weth.totalSupply(), amount);
        vm.stopPrank();
    }

    function testWithdraw(uint256 amount) public {
        address user = vm.addr(1);
        vm.deal(user, amount);

        vm.startPrank(user);
        weth.deposit{value: amount}();

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(user, amount);
        weth.withdraw(amount);
        assertEq(weth.balanceOf(user), 0);
        assertEq(weth.totalSupply(), 0);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, amount);

        vm.startPrank(user1);
        weth.deposit{value: amount}();

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, amount);
        weth.transfer(user2, amount);
        assertEq(weth.balanceOf(user1), 0);
        assertEq(weth.balanceOf(user2), amount);
        assertEq(weth.totalSupply(), amount);
        vm.stopPrank();
    }

    function testApproveAndTransferFrom(uint256 amount) public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, amount);

        vm.startPrank(user1);
        weth.deposit{value: amount}();

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, amount);
        weth.approve(user2, amount);
        vm.stopPrank();

        vm.startPrank(user2);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, amount);
        weth.transferFrom(user1, user2, amount);
        assertEq(weth.balanceOf(user1), 0);
        assertEq(weth.balanceOf(user2), amount);
        assertEq(weth.totalSupply(), amount);
        vm.stopPrank();
    }

    function testFallbackDeposit(uint256 amount) public {
        address user = vm.addr(1);
        vm.deal(user, amount);

        vm.startPrank(user);
        vm.expectEmit(true, false, false, true);
        emit Deposit(user, amount);
        (bool success, ) = address(weth).call{value: amount}("");
        assertTrue(success);
        assertEq(weth.balanceOf(user), amount);
        assertEq(weth.totalSupply(), amount);
        vm.stopPrank();
    }

    function testReceiveDeposit(uint256 amount) public {
        address user = vm.addr(1);
        vm.deal(user, amount);

        vm.startPrank(user);
        vm.expectEmit(true, false, false, true);
        emit Deposit(user, amount);
        (bool success, ) = address(weth).call{value: amount}("");
        assertTrue(success);
        assertEq(weth.balanceOf(user), amount);
        assertEq(weth.totalSupply(), amount);
        vm.stopPrank();
    }

    function testFailWithdrawInsufficientBalance(uint256 amount) public {
        address user = vm.addr(1);
        vm.deal(user, amount);

        vm.startPrank(user);
        weth.deposit{value: amount}();
        weth.withdraw(amount + 1);
        vm.stopPrank();
    }

    function testFailTransferInsufficientBalance(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max - 1);
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, amount);

        vm.startPrank(user1);
        weth.deposit{value: amount}();
        vm.expectRevert(bytes4(0x00000000));
        weth.transfer(user2, amount + 1);
        vm.stopPrank();
    }

    function testFailTransferFromInsufficientAllowance(uint256 amount) public {
        amount = bound(amount, 2, type(uint256).max);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, amount);

        vm.startPrank(user1);
        weth.deposit{value: amount}();
        weth.approve(user2, amount - 1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(bytes4(0x00000000));
        weth.transferFrom(user1, user2, amount);
        vm.stopPrank();
    }
}
