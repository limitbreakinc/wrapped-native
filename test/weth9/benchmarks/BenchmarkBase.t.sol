// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "src/IWrappedNative.sol";

abstract contract BenchmarkBase is Test {
    IWrappedNative public token;
    address public target;

    address public coldAccount = address(0x1234567890123456789012345678901234567890);
    address public warmAccount = address(0x1234567890123456789012345678901234567891);

     function createWrappedNativeInstance() public virtual;

    function setUp() public {
      createWrappedNativeInstance();
      target = address(0x000000000000000000000000000000000000dEaD);

      vm.deal(warmAccount, 100 ether);
      vm.deal(coldAccount, 100 ether);

      vm.prank(warmAccount);
      token.deposit{value: 10 ether}();
    }

    function testDepositWarmAccount() public {
      vm.prank(warmAccount);
      token.deposit{value: 20 ether}();
      
      assertEq(token.balanceOf(warmAccount), 30 ether);
    }

    function testDepositColdAccount() public {
      vm.prank(coldAccount);
      token.deposit{value: 20 ether}();
      
      assertEq(token.balanceOf(coldAccount), 20 ether);
    }

    function testWithdrawWarmAccount() public {
      vm.prank(warmAccount);
      token.withdraw(5 ether);
      
      assertEq(token.balanceOf(warmAccount), 5 ether);
    }

    function testTotalSupplyCold() public {
      uint supply = token.totalSupply();
      assertEq(supply, 10 ether);
    }

    function testTotalSupplyWarm() public {
      vm.prank(warmAccount);
      token.deposit{value: 10 ether}();
      uint supply = token.totalSupply();
      assertEq(supply, 20 ether);
    }

    /*
    function testTransfer() public {
      uint amount = 5000 * 10**6;
      token.transfer(target, amount);
    }

    function testApprove() public {
      uint amount = 5000 * 10**6;
      token.approve(address(this), amount);
    }

    function testTotalSupply() public {
      uint supply = token.totalSupply();

      assertEq(supply, 10000000 * 10**6);
    }

    function testAllowance() public {
      uint amount = 1000 * 10**6;
      address from = address(0xABCD);
      vm.prank(from);
      token.approve(address(this), amount);
      uint allowed = token.allowance(from, address(this));
      assertEq(allowed, amount);
    }

    function testTransferFrom() public {
      address from = address(0xABCD);

      token.transfer(from, 1e6);
      vm.prank(from);
      token.approve(address(this), 1e6);

      assertTrue(token.transferFrom(from, target, 1e6));
    }
    */
}
