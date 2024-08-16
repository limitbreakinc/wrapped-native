// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "src/WrappedNative.sol";
import "src/IWrappedNativeExtended.sol";
import "./WrappedNativeHandler.sol";

contract WrappedNativeInvariants is Test {
    IWrappedNativeExtended public wnative;
    WrappedNativeHandler public handler;

    function setUp() public {
        wnative = IWrappedNativeExtended(address(new WrappedNative()));
        handler = new WrappedNativeHandler(wnative);

        bytes4[] memory selectors = new bytes4[](21);
        selectors[0] = WrappedNativeHandler.deposit.selector;
        selectors[1] = WrappedNativeHandler.withdraw.selector;
        selectors[2] = WrappedNativeHandler.sendFallback.selector;
        selectors[3] = WrappedNativeHandler.approve.selector;
        selectors[4] = WrappedNativeHandler.transfer.selector;
        selectors[5] = WrappedNativeHandler.transferFrom.selector;
        selectors[6] = WrappedNativeHandler.depositTo.selector;
        selectors[7] = WrappedNativeHandler.withdrawToAccount.selector;
        selectors[8] = WrappedNativeHandler.withdrawSplit.selector;
        selectors[9] = WrappedNativeHandler.transferAutoDeposit.selector;
        selectors[10] = WrappedNativeHandler.transferFromAutoDeposit.selector;
        selectors[11] = WrappedNativeHandler.approveAutoDeposit.selector;
        selectors[12] = WrappedNativeHandler.permitTransferAutoDeposit.selector;
        selectors[13] = WrappedNativeHandler.doPermittedWithdrawal.selector;
        selectors[14] = WrappedNativeHandler.transferWrappedNativeToZeroAddress.selector;
        selectors[15] = WrappedNativeHandler.depositToZeroAddress.selector;
        selectors[16] = WrappedNativeHandler.recoverWNativeFromZeroAddress.selector;
        selectors[17] = WrappedNativeHandler.transferWrappedNativeToWrappedNativeAddress.selector;
        selectors[18] = WrappedNativeHandler.recoverStrandedTokens.selector;
        selectors[19] = WrappedNativeHandler.revokeMasterNonce.selector;
        selectors[20] = WrappedNativeHandler.revokeMyNonce.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));

        targetContract(address(handler));
    }

    // ETH can only be wrapped into WNATIVE, WNATIVE can only
    // be unwrapped back into ETH. The sum of the Handler's
    // ETH balance plus the WNATIVE totalSupply() should always
    // equal the total ETH_SUPPLY.
    function invariant_conservationOfETH() public {
        assertEq(ETH_SUPPLY, address(handler).balance + wnative.totalSupply());
    }

    // The WNATIVE contract's Ether balance should always be
    // at least as much as the sum of individual deposits
    function invariant_solvencyDeposits() public {
        assertEq(
            address(wnative).balance,
            handler.ghost_depositSum() + handler.ghost_forcePushSum() - handler.ghost_withdrawSum()
        );
    }

    // The WNATIVE contract's Ether balance should always be
    // at least as much as the sum of individual balances
    function invariant_solvencyBalances() public {
        uint256 sumOfBalances = handler.reduceActors(0, this.accumulateBalance);
        assertEq(address(wnative).balance - handler.ghost_forcePushSum(), sumOfBalances);
    }

    function accumulateBalance(uint256 balance, address caller) external view returns (uint256) {
        return balance + wnative.balanceOf(caller);
    }

    // No individual account balance can exceed the
    // WNATIVE totalSupply().
    function invariant_depositorBalances() public {
        handler.forEachActor(this.assertAccountBalanceLteTotalSupply);
    }

    function assertAccountBalanceLteTotalSupply(address account) external {
        assertLe(wnative.balanceOf(account), wnative.totalSupply());
    }

    function printAccountBalanceAndTotalSupply(address account) external {
        console.log("wnative.balanceOf(%s): %s", account, wnative.balanceOf(account));
        console.log("wnative.totalSupply(): %s", wnative.totalSupply());
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}