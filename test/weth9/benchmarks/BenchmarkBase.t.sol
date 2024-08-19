// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "src/IWrappedNative.sol";

abstract contract BenchmarkBase is Test {
    event  Approval(address indexed src, address indexed guy, uint256 wad);
    event  Transfer(address indexed src, address indexed dst, uint256 wad);
    event  Deposit(address indexed dst, uint256 wad);
    event  Withdrawal(address indexed src, uint256 wad);

    IWrappedNative public token;

    address public coldAccount = address(0x1234567890123456789012345678901234567890);
    address public warmAccount = address(0x1234567890123456789012345678901234567891);
    address public warmAccount2 = address(0x1234567890123456789012345678901234567892);
    address public warmAccount3 = address(0x1234567890123456789012345678901234567893);
    address public operator = address(0x1234567890123456789012345678901234567894);
    

     function createWrappedNativeInstance() public virtual;

    function setUp() public {
      createWrappedNativeInstance();

      vm.deal(warmAccount, 100 ether);
      vm.deal(coldAccount, 100 ether);
      vm.deal(warmAccount2, 100 ether);
      vm.deal(warmAccount3, 100 ether);

      vm.prank(warmAccount);
      token.deposit{value: 10 ether}();

      vm.prank(warmAccount2);
      token.deposit{value: 10 ether}();

      vm.prank(warmAccount3);
      token.deposit{value: 10 ether}();

      vm.prank(warmAccount);
      token.approve(operator, 50 ether);

      vm.prank(warmAccount3);
      token.approve(operator, type(uint256).max);
    }

    function testDepositWarmAccount() public {
      vm.expectEmit(true, false, false, true);
      emit Deposit(warmAccount, 20 ether);
      vm.prank(warmAccount);
      token.deposit{value: 20 ether}();
      
      assertEq(token.balanceOf(warmAccount), 30 ether);
    }

    function testDepositColdAccount() public {
      vm.expectEmit(true, false, false, true);
      emit Deposit(coldAccount, 20 ether);
      vm.prank(coldAccount);
      token.deposit{value: 20 ether}();
      
      assertEq(token.balanceOf(coldAccount), 20 ether);
    }

    function testWithdrawWarmAccount() public {
      vm.expectEmit(true, false, false, true);
      emit Withdrawal(warmAccount, 5 ether);
      vm.prank(warmAccount);
      token.withdraw(5 ether);
      
      assertEq(token.balanceOf(warmAccount), 5 ether);
    }

    function testTotalSupplyCold() public {
      uint supply = token.totalSupply();
      assertEq(supply, 30 ether);
    }

    function testTotalSupplyWarm() public {
      vm.prank(warmAccount);
      token.deposit{value: 10 ether}();
      uint supply = token.totalSupply();
      assertEq(supply, 40 ether);
    }

    function testApproveColdAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Approval(coldAccount, operator, 100 ether);
      vm.prank(coldAccount);
      token.approve(operator, 100 ether);
      
      assertEq(token.allowance(coldAccount, operator), 100 ether);
    }

    function testApproveWarmAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Approval(warmAccount, operator, 100 ether);
      vm.prank(warmAccount);
      token.approve(operator, 100 ether);
      
      assertEq(token.allowance(warmAccount, operator), 100 ether);
    }

    function testTransferWarmAccountToWarmAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Transfer(warmAccount, warmAccount2, 1 ether);
      vm.prank(warmAccount);
      token.transfer(warmAccount2, 1 ether);
      
      assertEq(token.balanceOf(warmAccount), 9 ether);
      assertEq(token.balanceOf(warmAccount2), 11 ether);
    }

    function testTransferWarmAccountToColdAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Transfer(warmAccount, coldAccount, 1 ether);
      vm.prank(warmAccount);
      token.transfer(coldAccount, 1 ether);
      
      assertEq(token.balanceOf(warmAccount), 9 ether);
      assertEq(token.balanceOf(coldAccount), 1 ether);
    }

    function testTransferColdAccountToWarmAccount() public {
      vm.prank(coldAccount);
      token.deposit{value: 10 ether}();

      vm.expectEmit(true, true, false, true);
      emit Transfer(coldAccount, warmAccount2, 1 ether);
      vm.prank(coldAccount);
      token.transfer(warmAccount2, 1 ether);
      
      assertEq(token.balanceOf(coldAccount), 9 ether);
      assertEq(token.balanceOf(warmAccount2), 11 ether);
    }

    function testOwnerInitiatedTransferFromWarmAccountToWarmAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Transfer(warmAccount, warmAccount2, 1 ether);
      vm.prank(warmAccount);
      token.transferFrom(warmAccount, warmAccount2, 1 ether);
      
      assertEq(token.balanceOf(warmAccount), 9 ether);
      assertEq(token.balanceOf(warmAccount2), 11 ether);
    }

    function testOwnerInitiatedTransferFromWarmAccountToColdAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Transfer(warmAccount, coldAccount, 1 ether);
      vm.prank(warmAccount);
      token.transferFrom(warmAccount, coldAccount, 1 ether);
      
      assertEq(token.balanceOf(warmAccount), 9 ether);
      assertEq(token.balanceOf(coldAccount), 1 ether);
    }

    function testOwnerInitiatedTransferFromColdAccountToWarmAccount() public {
      vm.prank(coldAccount);
      token.deposit{value: 10 ether}();

      vm.expectEmit(true, true, false, true);
      emit Transfer(coldAccount, warmAccount2, 1 ether);
      vm.prank(coldAccount);
      token.transferFrom(coldAccount, warmAccount2, 1 ether);
      
      assertEq(token.balanceOf(coldAccount), 9 ether);
      assertEq(token.balanceOf(warmAccount2), 11 ether);
    }

    function testOperatorInitiatedTransferFromWarmAccountToWarmAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Transfer(warmAccount, warmAccount2, 1 ether);
      vm.prank(operator);
      token.transferFrom(warmAccount, warmAccount2, 1 ether);
      
      assertEq(token.balanceOf(warmAccount), 9 ether);
      assertEq(token.balanceOf(warmAccount2), 11 ether);
    }

    function testOperatorInitiatedTransferFromWarmAccountToColdAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Transfer(warmAccount, coldAccount, 1 ether);
      vm.prank(operator);
      token.transferFrom(warmAccount, coldAccount, 1 ether);
      
      assertEq(token.balanceOf(warmAccount), 9 ether);
      assertEq(token.balanceOf(coldAccount), 1 ether);
    }

    function testOperatorInitiatedTransferFromColdAccountToWarmAccount() public {
      vm.prank(coldAccount);
      token.deposit{value: 10 ether}();

      vm.prank(coldAccount);
      token.approve(operator, 50 ether);

      vm.expectEmit(true, true, false, true);
      emit Transfer(coldAccount, warmAccount2, 1 ether);
      vm.prank(operator);
      token.transferFrom(coldAccount, warmAccount2, 1 ether);
      
      assertEq(token.balanceOf(coldAccount), 9 ether);
      assertEq(token.balanceOf(warmAccount2), 11 ether);
    }

    function testOperatorInitiatedUnlimitedTransferFromWarmAccountToWarmAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Transfer(warmAccount3, warmAccount2, 1 ether);
      vm.prank(operator);
      token.transferFrom(warmAccount3, warmAccount2, 1 ether);
      
      assertEq(token.balanceOf(warmAccount3), 9 ether);
      assertEq(token.balanceOf(warmAccount2), 11 ether);
    }

    function testOperatorInitiatedUnlimitedTransferFromWarmAccountToColdAccount() public {
      vm.expectEmit(true, true, false, true);
      emit Transfer(warmAccount3, coldAccount, 1 ether);
      vm.prank(operator);
      token.transferFrom(warmAccount3, coldAccount, 1 ether);
      
      assertEq(token.balanceOf(warmAccount3), 9 ether);
      assertEq(token.balanceOf(coldAccount), 1 ether);
    }

    function testOperatorInitiatedUnlimitedTransferFromColdAccountToWarmAccount() public {
      vm.prank(coldAccount);
      token.deposit{value: 10 ether}();

      vm.prank(coldAccount);
      token.approve(operator, type(uint256).max);

      vm.expectEmit(true, true, false, true);
      emit Transfer(coldAccount, warmAccount2, 1 ether);
      vm.prank(operator);
      token.transferFrom(coldAccount, warmAccount2, 1 ether);
      
      assertEq(token.balanceOf(coldAccount), 9 ether);
      assertEq(token.balanceOf(warmAccount2), 11 ether);
    }
}
