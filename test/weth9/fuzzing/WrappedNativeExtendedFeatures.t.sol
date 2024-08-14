pragma solidity 0.8.26;

import "./WrappedNative.t.sol";
import "src/IWrappedNativeExtended.sol";
import "src/utils/MessageHashUtils.sol";

import "test/mocks/ContractMockRejectsNative.sol";
import "test/mocks/ERC20Mock.sol";
import "test/mocks/ERC721Mock.sol";
import "test/mocks/ERC1155Mock.sol";

contract WrappedNativeExtendedFeaturesTest is WrappedNativeTest {
    event PermitNonceInvalidated(address indexed account,uint256 indexed nonce);
    event MasterNonceInvalidated(address indexed account, uint256 indexed nonce);

    //===========================================================
    //== Deposit / Receive / Fallback Function Implementations ==
    //===========================================================

    function testRevertsWhenNoValueIsSentWithCalldataThatIsNotAnImplementedSelector(bytes4 selector, bytes memory argData) public {
        selector = _sanitizeBadSelectorFallbackImplementation(selector);
        selector = _sanitizeBadSelectorImplementedFunctions(selector);
        vm.expectRevert();
        address(weth).call{value: 0}(abi.encodeWithSelector(selector, argData));
    }

    function testReturnsUnsuccessfulWhenNoValueIsSentWithCalldataThatIsNotAnImplementedSelector(bytes4 selector, bytes memory argData) public {
        selector = _sanitizeBadSelectorFallbackImplementation(selector);
        selector = _sanitizeBadSelectorImplementedFunctions(selector);
        (bool success, ) = address(weth).call{value: 0}(abi.encodeWithSelector(selector, argData));
        assertFalse(success);
    }

    function testDepositSucceedsWhenValueIsSentWithoutCalldata(address depositor, uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        vm.deal(depositor, amount);
        vm.prank(depositor);
        vm.expectEmit(true, false, false, true);
        emit Deposit(depositor, amount);
        address(weth).call{value: amount}("");
        assertEq(weth.balanceOf(depositor), amount);
    }

    function testDepositSucceedsWhenValueIsSentWithCalldata(bytes4 selector, bytes memory argData, address depositor, uint256 amount) public {
        selector = _sanitizeBadSelectorImplementedFunctions(selector);
        amount = bound(amount, 1, type(uint256).max);
        vm.deal(depositor, amount);
        vm.prank(depositor);
        vm.expectEmit(true, false, false, true);
        emit Deposit(depositor, amount);
        address(weth).call{value: amount}(abi.encodeWithSelector(selector, argData));
        assertEq(weth.balanceOf(depositor), amount);
    }

    function testDeposit(address depositor, uint256 amount) public {
        vm.deal(depositor, amount);
        vm.prank(depositor);
        vm.expectEmit(true, false, false, true);
        emit Deposit(depositor, amount);
        weth.deposit{value: amount}();
        assertEq(weth.balanceOf(depositor), amount);
    }

    function testDepositToWhereDepositorAddressIsNotToAddress(address depositor, address to, uint256 amount) public {
        vm.assume(depositor != to);
        vm.deal(depositor, amount);
        vm.prank(depositor);
        vm.expectEmit(true, false, false, true);
        emit Deposit(to, amount);
        IWrappedNativeExtended(address(weth)).depositTo{value: amount}(to);
        assertEq(weth.balanceOf(to), amount);
        assertEq(weth.balanceOf(depositor), 0);
    }

    function testFallbackImplementationOfIsNonceUsed(address account, uint256 nonce) public {
        assertFalse(IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
        (bool success, bytes memory returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_IS_NONCE_USED, account, nonce));
        assertTrue(success);
        assertEq(returndata.length, 32);
        assertEq(abi.decode(returndata, (bool)), false);

        vm.prank(account);
        IWrappedNativeExtended(address(weth)).revokeMyNonce(nonce);

        assertTrue(IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
        (success, returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_IS_NONCE_USED, account, nonce));
        assertTrue(success);
        assertEq(returndata.length, 32);
        assertEq(abi.decode(returndata, (bool)), true);
    }

    function testFallbackImplementationOfMasterNonces(address account) public {
        assertEq(IWrappedNativeExtended(address(weth)).masterNonces(account), 0);
        (bool success, bytes memory returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_MASTER_NONCES, account));
        assertTrue(success);
        assertEq(returndata.length, 32);
        assertEq(abi.decode(returndata, (uint256)), 0);

        vm.prank(account);
        IWrappedNativeExtended(address(weth)).revokeMyOutstandingPermits();

        assertEq(IWrappedNativeExtended(address(weth)).masterNonces(account), 1);
        (success, returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_MASTER_NONCES, account));
        assertTrue(success);
        assertEq(returndata.length, 32);
        assertEq(abi.decode(returndata, (uint256)), 1);
    }
    
    function testFallbackImplementationOfTotalSupply(uint256 supply) public {
        vm.deal(address(this), supply);
        weth.deposit{value: supply}();
        assertEq(weth.totalSupply(), supply);
        (bool success, bytes memory returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_TOTAL_SUPPLY));
        assertTrue(success);
        assertEq(returndata.length, 32);
        assertEq(abi.decode(returndata, (uint256)), supply);
    }

    function testFallbackImplementationOfDomainSeparatorV4() public {
        bytes32 expectedDomainSeparator = 
        keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), 
                keccak256(bytes(NAME)), 
                keccak256(bytes(VERSION)), 
                block.chainid, 
                address(weth)
            )
        );

        assertEq(IWrappedNativeExtended(address(weth)).domainSeparatorV4(), expectedDomainSeparator);
        (bool success, bytes memory returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_DOMAIN_SEPARATOR_V4));
        assertTrue(success);
        assertEq(returndata.length, 32);
        assertEq(abi.decode(returndata, (bytes32)), expectedDomainSeparator);
    }

    function testFallbackImplementationOfName() public {
        assertEq(weth.name(), NAME);
        (bool success, bytes memory returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_NAME));
        assertTrue(success);
        assertEq(returndata.length, 96);
        assertEq(abi.decode(returndata, (string)), NAME);
    }

    function testFallbackImplementationOfSymbol() public {
        assertEq(weth.symbol(), SYMBOL);
        (bool success, bytes memory returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_SYMBOL));
        assertTrue(success);
        assertEq(returndata.length, 96);
        assertEq(abi.decode(returndata, (string)), SYMBOL);
    }

    function testFallbackImplementationOfDecimals() public {
        assertEq(weth.decimals(), DECIMALS);
        (bool success, bytes memory returndata) = address(weth).call(abi.encodeWithSelector(SELECTOR_DECIMALS));
        assertTrue(success);
        assertEq(returndata.length, 32);
        assertEq(abi.decode(returndata, (uint8)), DECIMALS);
    }

    //=================================================
    //===================== Withdrawals ===============
    //=================================================

    function testWithdrawUsingOwnAccount(address account, uint256 depositedAmount, uint256 withdrawalAmount) public {
        _sanitizeAddress(account, new address[](0));
        withdrawalAmount = bound(withdrawalAmount, 0, depositedAmount);
        vm.deal(account, depositedAmount);
        vm.startPrank(account);
        weth.deposit{value: depositedAmount}();
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(account, withdrawalAmount);
        weth.withdraw(withdrawalAmount);
        assertEq(weth.balanceOf(account), depositedAmount - withdrawalAmount);
        assertEq(account.balance, withdrawalAmount);
        vm.stopPrank();
    }

    function testWithdrawUsingOwnAccountAfterReceivingWrappedToken(
        address depositorAccount, 
        address withdrawerAccount, 
        uint256 depositedAmount, 
        uint256 withdrawalAmount
    ) public {
        _sanitizeAddress(depositorAccount, new address[](0));
        _sanitizeAddress(withdrawerAccount, new address[](0));
        withdrawalAmount = bound(withdrawalAmount, 0, depositedAmount);
        vm.deal(depositorAccount, depositedAmount);
        vm.startPrank(depositorAccount);
        weth.deposit{value: depositedAmount}();
        weth.transfer(withdrawerAccount, depositedAmount);
        vm.stopPrank();
        vm.startPrank(withdrawerAccount);
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(withdrawerAccount, withdrawalAmount);
        weth.withdraw(withdrawalAmount);
        vm.stopPrank();

        assertEq(weth.balanceOf(withdrawerAccount), depositedAmount - withdrawalAmount);
        assertEq(withdrawerAccount.balance, withdrawalAmount);

        if (withdrawerAccount != depositorAccount) {
            assertEq(weth.balanceOf(depositorAccount), 0);
        }
    }

    function testWithdrawToOwnAccount(address account, uint256 depositedAmount, uint256 withdrawalAmount) public {
        _sanitizeAddress(account, new address[](0));
        withdrawalAmount = bound(withdrawalAmount, 0, depositedAmount);
        vm.deal(account, depositedAmount);
        vm.startPrank(account);
        weth.deposit{value: depositedAmount}();
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(account, withdrawalAmount);
        IWrappedNativeExtended(address(weth)).withdrawToAccount(account, withdrawalAmount);
        assertEq(weth.balanceOf(account), depositedAmount - withdrawalAmount);
        assertEq(account.balance, withdrawalAmount);
        vm.stopPrank();
    }

    function testWithdrawToAnotherAccount(address account, address to, uint256 depositedAmount, uint256 withdrawalAmount) public {
        _sanitizeAddress(account, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(account != to);
        withdrawalAmount = bound(withdrawalAmount, 0, depositedAmount);
        vm.deal(account, depositedAmount);
        vm.startPrank(account);
        weth.deposit{value: depositedAmount}();
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(account, withdrawalAmount);
        IWrappedNativeExtended(address(weth)).withdrawToAccount(to, withdrawalAmount);
        assertEq(weth.balanceOf(account), depositedAmount - withdrawalAmount);
        assertEq(to.balance, withdrawalAmount);
        vm.stopPrank();
    }

    function testWithdrawSplit(address depositorAccount, address[] memory toAddresses, uint256[] memory amounts, uint256 maxArraySize) public {
        maxArraySize = bound(Math.min(10, maxArraySize), 0, Math.min(toAddresses.length, amounts.length));

        assembly {
            mstore(toAddresses, maxArraySize)
            mstore(amounts, maxArraySize)
        }

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < maxArraySize; ++i) {
            _sanitizeAddress(toAddresses[i], new address[](0));
            amounts[i] = bound(amounts[i], 0, type(uint128).max);
            totalAmount += amounts[i];
        }

        uint256[] memory amountsForAccount = _aggregateAmountsByAddress(toAddresses, amounts);

        _sanitizeAddress(depositorAccount, toAddresses);
        vm.deal(depositorAccount, totalAmount);
        vm.startPrank(depositorAccount);
        weth.deposit{value: totalAmount}();
        for (uint256 i = 0; i < toAddresses.length; ++i) {
            vm.expectEmit(true, false, false, true);
            emit Withdrawal(depositorAccount, amounts[i]);
        }
        IWrappedNativeExtended(address(weth)).withdrawSplit(toAddresses, amounts);
        assertEq(weth.balanceOf(depositorAccount), 0);
        for (uint256 i = 0; i < toAddresses.length; ++i) {
            assertEq(toAddresses[i].balance, amountsForAccount[i]);
        }
        vm.stopPrank();
    }

    function testWithdrawRevertsOnOverdraft(address account, uint256 depositedAmount, uint256 withdrawalAmount) public {
        _sanitizeAddress(account, new address[](0));
        depositedAmount = bound(depositedAmount, 0, type(uint256).max - 1);
        withdrawalAmount = bound(withdrawalAmount, depositedAmount + 1, type(uint256).max);
        vm.deal(account, depositedAmount);
        vm.startPrank(account);
        weth.deposit{value: depositedAmount}();
        vm.expectRevert();
        weth.withdraw(withdrawalAmount);
        vm.stopPrank();
    }

    function testWithdrawToRevertsOnOverdraft(address account, address to, uint256 depositedAmount, uint256 withdrawalAmount) public {
        _sanitizeAddress(account, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(account != to);
        depositedAmount = bound(depositedAmount, 0, type(uint256).max - 1);
        withdrawalAmount = bound(withdrawalAmount, depositedAmount + 1, type(uint256).max);
        vm.deal(account, depositedAmount);
        vm.startPrank(account);
        weth.deposit{value: depositedAmount}();
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).withdrawToAccount(to, withdrawalAmount);
        vm.stopPrank();
    }

    function testWithdrawSplitRevertsOnOverdraft(address account, address[] memory toAddresses, uint256[] memory amounts, uint256 maxArraySize) public {
        maxArraySize = bound(Math.min(10, maxArraySize), 0, Math.min(toAddresses.length, amounts.length));

        assembly {
            mstore(toAddresses, maxArraySize)
            mstore(amounts, maxArraySize)
        }

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < maxArraySize; ++i) {
            _sanitizeAddress(toAddresses[i], new address[](0));
            amounts[i] = bound(amounts[i], 0, type(uint128).max);
            totalAmount += amounts[i];
        }

        vm.assume(totalAmount > 0);

        uint256[] memory amountsForAccount = _aggregateAmountsByAddress(toAddresses, amounts);

        _sanitizeAddress(account, toAddresses);
        vm.deal(account, totalAmount - 1);
        vm.startPrank(account);
        weth.deposit{value: totalAmount - 1}();
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).withdrawSplit(toAddresses, amounts);
        vm.stopPrank();
    }

    function testWithdrawRevertsOnRejectedNativeTransfer(uint256 depositedAmount, uint256 withdrawalAmount) public {
        address badReceiver = address(new ContractMockRejectsNative());
        depositedAmount = bound(depositedAmount, 1, type(uint256).max);
        withdrawalAmount = bound(withdrawalAmount, 0, depositedAmount);
        vm.deal(badReceiver, depositedAmount);
        vm.startPrank(badReceiver);
        weth.deposit{value: depositedAmount}();
        vm.expectRevert();
        weth.withdraw(withdrawalAmount);
        vm.stopPrank();
    }

    function testWithdrawToRevertsOnRjectedNativeTransfer(address account, uint256 depositedAmount, uint256 withdrawalAmount) public {
        address badReceiver = address(new ContractMockRejectsNative());
        _sanitizeAddress(account, new address[](0));
        depositedAmount = bound(depositedAmount, 1, type(uint256).max);
        withdrawalAmount = bound(withdrawalAmount, 0, depositedAmount);
        vm.deal(account, depositedAmount);
        vm.startPrank(account);
        weth.deposit{value: depositedAmount}();
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).withdrawToAccount(badReceiver, withdrawalAmount);
        vm.stopPrank();
    }

    function testWithdrawSplitRevertsOnRejectedNativeTransfer(address account, address[] memory toAddresses, uint256[] memory amounts, uint256 maxArraySize) public {
        address badReceiver = address(new ContractMockRejectsNative());
        maxArraySize = bound(Math.min(10, maxArraySize), 0, Math.min(toAddresses.length, amounts.length));

        assembly {
            mstore(toAddresses, maxArraySize)
            mstore(amounts, maxArraySize)
        }

        vm.assume(maxArraySize > 0);

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < maxArraySize; ++i) {
            _sanitizeAddress(toAddresses[i], new address[](0));
            amounts[i] = bound(amounts[i], 0, type(uint128).max);
            totalAmount += amounts[i];
        }

        toAddresses[toAddresses.length - 1] = badReceiver;

        vm.assume(totalAmount > 0);

        uint256[] memory amountsForAccount = _aggregateAmountsByAddress(toAddresses, amounts);

        vm.deal(account, totalAmount);
        vm.startPrank(account);
        weth.deposit{value: totalAmount}();
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).withdrawSplit(toAddresses, amounts);
        vm.stopPrank();
    }

    //=================================================
    //======= Permitted Transfers / Withdrawals =======
    //=================================================

    function testRevokeMyOutstandingPermits(address account) public {
        _sanitizeAddress(account, new address[](0));
        for (uint256 i = 0; i < 10; i++) {
            uint256 previousMasterNonce = IWrappedNativeExtended(address(weth)).masterNonces(account);
            vm.expectEmit(true, true, false, false);
            emit MasterNonceInvalidated(account, previousMasterNonce);
            vm.prank(account);
            IWrappedNativeExtended(address(weth)).revokeMyOutstandingPermits();
            uint256 updatedMasterNonce = IWrappedNativeExtended(address(weth)).masterNonces(account);
            assertEq(updatedMasterNonce - previousMasterNonce, 1);
        }
    }

    function testRevokeMyNonce(address account, uint256 nonce) public {
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
        _sanitizeAddress(account, new address[](0));
        vm.prank(account);
        vm.expectEmit(true, true, false, false);
        emit PermitNonceInvalidated(account, nonce);
        IWrappedNativeExtended(address(weth)).revokeMyNonce(nonce);
        assertTrue(IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
    }

    function testRevokeConsecutiveNonces(address account) public {
        _sanitizeAddress(account, new address[](0));

        vm.startPrank(account);
        for (uint256 nonce = 0; nonce < 512; nonce++) {
            vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
            vm.expectEmit(true, true, false, false);
            emit PermitNonceInvalidated(account, nonce);
            IWrappedNativeExtended(address(weth)).revokeMyNonce(nonce);
            assertTrue(IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
        }

        for (uint256 nonce = type(uint256).max - 512; nonce < type(uint256).max; nonce++) {
            vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
            vm.expectEmit(true, true, false, false);
            emit PermitNonceInvalidated(account, nonce);
            IWrappedNativeExtended(address(weth)).revokeMyNonce(nonce);
            assertTrue(IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
        }
        vm.stopPrank();
    }

    function testRevokeMyNonceRevertsWhenNonceIsAlreadyUsed(address account, uint256 nonce) public {
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
        _sanitizeAddress(account, new address[](0));
        vm.startPrank(account);
        IWrappedNativeExtended(address(weth)).revokeMyNonce(nonce);
        assertTrue(IWrappedNativeExtended(address(weth)).isNonceUsed(account, nonce));
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).revokeMyNonce(nonce);
        vm.stopPrank();
    }

    function testPermitTransferNoAutoDeposit(uint160 fromKey, address operator, address to, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        transferAmount = bound(transferAmount, 0, permitAmount);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, permitAmount);
        vm.prank(from);
        weth.deposit{value: permitAmount}();

        vm.prank(operator);
        vm.expectEmit(true, true, false, false);
        emit PermitNonceInvalidated(from, nonce);
        vm.expectEmit(true, true, false, true);
        emit Transfer(from, to, transferAmount);
        IWrappedNativeExtended(address(weth)).permitTransfer(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );

        if (from != to) {
            assertEq(weth.balanceOf(from), permitAmount - transferAmount);
            assertEq(weth.balanceOf(to), transferAmount);
        } else {
            assertEq(weth.balanceOf(from), permitAmount);
        }

        assertTrue(IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
    }

    function testPermitTransferWithAutoDeposit(uint160 fromKey, address operator, address to, uint256 autodepositAmount, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        autodepositAmount = bound(autodepositAmount, 0, permitAmount);
        transferAmount = bound(transferAmount, 0, permitAmount);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, permitAmount - autodepositAmount);
        vm.deal(operator, autodepositAmount);
        vm.prank(from);
        weth.deposit{value: permitAmount - autodepositAmount}();

        vm.prank(operator);
        if (autodepositAmount > 0) {
            vm.expectEmit(true, false, false, true);
            emit Deposit(from, autodepositAmount);
        }
        vm.expectEmit(true, true, false, false);
        emit PermitNonceInvalidated(from, nonce);
        vm.expectEmit(true, true, false, true);
        emit Transfer(from, to, transferAmount);
        IWrappedNativeExtended(address(weth)).permitTransfer{value: autodepositAmount}(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );

        if (from != to) {
            assertEq(weth.balanceOf(from), permitAmount - transferAmount);
            assertEq(weth.balanceOf(to), transferAmount);
        } else {
            assertEq(weth.balanceOf(from), permitAmount);
        }

        assertTrue(IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
    }

    function testPermitTransferRevertsWhenBalanceIsInsufficient(uint160 fromKey, address operator, address to, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration, uint256 shortfall) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        permitAmount = bound(permitAmount, 1, type(uint256).max);
        transferAmount = bound(transferAmount, 1, permitAmount);
        shortfall = bound(shortfall, 0, transferAmount - 1);
        if (shortfall == 0) {
            shortfall = 1;
        }
        uint256 depositAmount = transferAmount - shortfall;
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, depositAmount);
        vm.prank(from);
        weth.deposit{value: depositAmount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).permitTransfer(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );
    }

    function testPermitTransferRevertsWhenTransferAmountExceedsPermittedAmount(uint160 fromKey, address operator, address to, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        permitAmount = bound(permitAmount, 0, type(uint256).max - 1);
        transferAmount = bound(transferAmount, permitAmount + 1, type(uint256).max);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, permitAmount);
        vm.prank(from);
        weth.deposit{value: permitAmount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).permitTransfer(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );
    }

    function testPermitTransferRevertsWhenPermitIsExpired(uint160 fromKey, address operator, address to, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration, uint256 secondsPastExpiration) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        permitAmount = bound(permitAmount, 0, type(uint256).max);
        transferAmount = bound(transferAmount, 0, permitAmount);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - 1 - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;
        uint256 pastExpiration = bound(secondsPastExpiration, 1, type(uint256).max - expiration);
        vm.warp(expiration + pastExpiration);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, permitAmount);
        vm.prank(from);
        weth.deposit{value: permitAmount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).permitTransfer(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );
    }

    function testPermitTransferRevertsWhenFromIsZero(address operator, address to, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration) public {
        address from = address(0);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(to, new address[](0));
        transferAmount = bound(transferAmount, 0, permitAmount);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1000, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, permitAmount);
        vm.prank(from);
        weth.deposit{value: permitAmount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).permitTransfer(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );
    }

    function testPermitTransferRevertsWhenNonceIsUsed(uint160 fromKey, address operator, address to, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        transferAmount = bound(transferAmount, 0, permitAmount);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, permitAmount);
        vm.startPrank(from);
        weth.deposit{value: permitAmount}();
        IWrappedNativeExtended(address(weth)).revokeMyNonce(nonce);
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).permitTransfer(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );
    }

    function testPermitTransferRevertsWhenMasterNonceIsRevoked(uint160 fromKey, address operator, address to, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        transferAmount = bound(transferAmount, 0, permitAmount);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, permitAmount);
        vm.startPrank(from);
        weth.deposit{value: permitAmount}();
        IWrappedNativeExtended(address(weth)).revokeMyOutstandingPermits();
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).permitTransfer(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );
    }

    function testPermitTransferRevertsWhenPermitNotSignedByFromAccount(uint160 fromKey, uint160 signerKey, address operator, address to, uint256 transferAmount, uint256 permitAmount, uint256 nonce, uint256 secondsToExpiration) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        signerKey = uint160(bound(signerKey, 2048, type(uint160).max));
        vm.assume(fromKey != signerKey);
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        transferAmount = bound(transferAmount, 0, permitAmount);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        operator,
                        permitAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from)
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, permitAmount);
        vm.startPrank(from);
        weth.deposit{value: permitAmount}();
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).permitTransfer(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit
        );
    }

    function testDoPermittedWithdrawal(uint160 fromKey, address operator, address to, uint256 amount, uint256 nonce, uint256 secondsToExpiration, address convenienceFeeReceiver, uint256 convenienceFeeBps) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(to != convenienceFeeReceiver);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);
        amount = bound(amount, 0, type(uint240).max);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        operator,
                        amount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, amount);
        vm.prank(from);
        weth.deposit{value: amount}();

        vm.prank(operator);

        vm.expectEmit(true, true, false, false);
        emit PermitNonceInvalidated(from, nonce);

        if (convenienceFee > 0) {
            vm.expectEmit(true, true, false, true);
            emit Transfer(from, convenienceFeeReceiver, convenienceFee);
        }

        if (convenienceFeeInfrastructure > 0) {
            vm.expectEmit(true, true, false, true);
            emit Transfer(from, ADDRESS_INFRASTRUCTURE_TAX, convenienceFeeInfrastructure);
        }

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(from, userAmount);

        IWrappedNativeExtended(address(weth)).doPermittedWithdraw(
            from, 
            to, 
            amount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver,
            convenienceFeeBps,
            signedPermit
        );

        assertTrue(IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));

        assertEq(to.balance, userAmount);
        assertEq(weth.balanceOf(ADDRESS_INFRASTRUCTURE_TAX), convenienceFeeInfrastructure);
        if (convenienceFeeReceiver != address(0)) {
            assertEq(weth.balanceOf(convenienceFeeReceiver), convenienceFee);
        }
    }

    function testDoPermittedWithdrawalRevertsWhenBalanceIsInsufficient(uint160 fromKey, address operator, address to, uint256 amount, uint256 nonce, uint256 secondsToExpiration, address convenienceFeeReceiver, uint256 convenienceFeeBps, uint256 shortfall) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(to != convenienceFeeReceiver);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);
        amount = bound(amount, 1, type(uint240).max);
        shortfall = bound(shortfall, 0, amount - 1);
        if (shortfall == 0) {
            shortfall = 1;
        }
        uint256 depositAmount = amount - shortfall;
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        operator,
                        amount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, depositAmount);
        vm.prank(from);
        weth.deposit{value: depositAmount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).doPermittedWithdraw(
            from, 
            to, 
            amount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver,
            convenienceFeeBps,
            signedPermit
        );
    }

    function testDoPermittedWithdrawalRevertsWhenAmountExceedsPermit(uint160 fromKey, address operator, address to, uint256 amount, uint256 permittedAmount, uint256 nonce, uint256 secondsToExpiration, address convenienceFeeReceiver, uint256 convenienceFeeBps) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(to != convenienceFeeReceiver);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);
        permittedAmount = bound(permittedAmount, 0, type(uint240).max - 1);
        amount = bound(amount, permittedAmount + 1, type(uint240).max);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        operator,
                        permittedAmount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, amount);
        vm.prank(from);
        weth.deposit{value: amount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).doPermittedWithdraw(
            from, 
            to, 
            amount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver,
            convenienceFeeBps,
            signedPermit
        );
    }

    function testDoPermittedWithdrawalRevertsWhenPermitIsExpired(uint160 fromKey, address operator, address to, uint256 amount, uint256 nonce, uint256 secondsToExpiration, address convenienceFeeReceiver, uint256 convenienceFeeBps, uint256 secondsPastExpiration) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(to != convenienceFeeReceiver);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);
        amount = bound(amount, 0, type(uint240).max);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - 1 - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;
        uint256 pastExpiration = bound(secondsPastExpiration, 1, type(uint256).max - expiration);
        vm.warp(expiration + pastExpiration);

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        operator,
                        amount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, amount);
        vm.prank(from);
        weth.deposit{value: amount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).doPermittedWithdraw(
            from, 
            to, 
            amount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver,
            convenienceFeeBps,
            signedPermit
        );
    }

    function testDoPermittedWithdrawalRevertsWhenFromIsZero(address operator, address to, uint256 amount, uint256 nonce, uint256 secondsToExpiration, address convenienceFeeReceiver, uint256 convenienceFeeBps) public {
        address from = address(0);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(to != convenienceFeeReceiver);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);
        amount = bound(amount, 0, type(uint240).max);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        operator,
                        amount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1000, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, amount);
        vm.prank(from);
        weth.deposit{value: amount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).doPermittedWithdraw(
            from, 
            to, 
            amount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver,
            convenienceFeeBps,
            signedPermit
        );
    }

    function testDoPermittedWithdrawalRevertsWhenNonceIsUsed(uint160 fromKey, address operator, address to, uint256 amount, uint256 nonce, uint256 secondsToExpiration, address convenienceFeeReceiver, uint256 convenienceFeeBps) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(to != convenienceFeeReceiver);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);
        amount = bound(amount, 0, type(uint240).max);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        operator,
                        amount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, amount);
        vm.startPrank(from);
        weth.deposit{value: amount}();
        IWrappedNativeExtended(address(weth)).revokeMyNonce(nonce);
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).doPermittedWithdraw(
            from, 
            to, 
            amount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver,
            convenienceFeeBps,
            signedPermit
        );
    }

    function testDoPermittedWithdrawalRevertsWhenMasterNonceIsRevoked(uint160 fromKey, address operator, address to, uint256 amount, uint256 nonce, uint256 secondsToExpiration, address convenienceFeeReceiver, uint256 convenienceFeeBps) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(to != convenienceFeeReceiver);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);
        amount = bound(amount, 0, type(uint240).max);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        operator,
                        amount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, amount);
        vm.startPrank(from);
        weth.deposit{value: amount}();
        IWrappedNativeExtended(address(weth)).revokeMyOutstandingPermits();
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).doPermittedWithdraw(
            from, 
            to, 
            amount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver,
            convenienceFeeBps,
            signedPermit
        );
    }

    function testDoPermittedWithdrawalRevertsWhenPermitNotSignedByFromAccount(uint160 fromKey, uint160 signerKey, address operator, address to, uint256 amount, uint256 nonce, uint256 secondsToExpiration, address convenienceFeeReceiver, uint256 convenienceFeeBps) public {
        fromKey = uint160(bound(fromKey, 2048, type(uint160).max));
        signerKey = uint160(bound(signerKey, 2048, type(uint160).max));
        vm.assume(fromKey != signerKey);
        address from = vm.addr(fromKey);
        _sanitizeAddress(operator, new address[](0));
        _sanitizeAddress(from, new address[](0));
        _sanitizeAddress(to, new address[](0));
        vm.assume(to != convenienceFeeReceiver);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);
        amount = bound(amount, 0, type(uint240).max);
        vm.assume(!IWrappedNativeExtended(address(weth)).isNonceUsed(from, nonce));
        secondsToExpiration = bound(secondsToExpiration, 0, type(uint256).max - block.timestamp);
        uint256 expiration = block.timestamp + secondsToExpiration;

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        bytes32 domainSeparator = IWrappedNativeExtended(address(weth)).domainSeparatorV4();
        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                IWrappedNativeExtended(address(weth)).domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        operator,
                        amount,
                        nonce,
                        expiration,
                        IWrappedNativeExtended(address(weth)).masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        vm.deal(from, amount);
        vm.prank(from);
        weth.deposit{value: amount}();

        vm.prank(operator);
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).doPermittedWithdraw(
            from, 
            to, 
            amount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver,
            convenienceFeeBps,
            signedPermit
        );
    }

    //=================================================
    //=============== Recovery Functions ==============
    //=================================================

    function testRecoverStrandedWNativeFromZeroAddress(address mev, address to, uint256 amount) public {
        _sanitizeAddress(mev, new address[](0));
        _sanitizeAddress(to, new address[](0));

        amount = bound(amount, 0, type(uint256).max / INFRASTRUCTURE_TAX_BPS);

        uint256 recoveryTaxAmount = amount * INFRASTRUCTURE_TAX_BPS / FEE_DENOMINATOR;
        uint256 mevAmount = amount - recoveryTaxAmount;

        vm.deal(address(this), amount);
        IWrappedNativeExtended(address(weth)).depositTo{value: amount}(ADDRESS_ZERO);
        
        vm.prank(mev);
        vm.expectEmit(true, true, false, true);
        emit Transfer(ADDRESS_ZERO, ADDRESS_INFRASTRUCTURE_TAX, recoveryTaxAmount);
        vm.expectEmit(true, true, false, true);
        emit Transfer(ADDRESS_ZERO, to, mevAmount);
        IWrappedNativeExtended(address(weth)).recoverWNativeFromZeroAddress(to, amount);

        assertEq(weth.balanceOf(ADDRESS_INFRASTRUCTURE_TAX), recoveryTaxAmount);
        assertEq(weth.balanceOf(to), mevAmount);
    }

    function testRecoverStrandedTokensWNative(address mev, address to, uint256 tokenId, uint256 recoverAmount, uint256 strandedAmount) public {
        strandedAmount = bound(strandedAmount, 0, type(uint256).max / INFRASTRUCTURE_TAX_BPS);
        recoverAmount = bound(recoverAmount, 0, strandedAmount);

        uint256 recoveryTaxAmount = recoverAmount * INFRASTRUCTURE_TAX_BPS / FEE_DENOMINATOR;
        uint256 mevAmount = recoverAmount - recoveryTaxAmount;

        _sanitizeAddress(mev, new address[](0));
        _sanitizeAddress(to, new address[](0));

        vm.deal(address(this), strandedAmount);
        IWrappedNativeExtended(address(weth)).depositTo{value: strandedAmount}(address(weth));

        vm.prank(mev);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(weth), ADDRESS_INFRASTRUCTURE_TAX, recoveryTaxAmount);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(weth), to, mevAmount);
        IWrappedNativeExtended(address(weth)).recoverStrandedTokens(TOKEN_STANDARD_ERC20, address(weth), to, tokenId, recoverAmount);

        assertEq(weth.balanceOf(ADDRESS_INFRASTRUCTURE_TAX), recoveryTaxAmount);
        assertEq(weth.balanceOf(to), mevAmount);
    }

    function testRecoverStrandedTokensERC20(address mev, address to, uint256 tokenId, uint256 recoverAmount, uint256 strandedAmount) public {
        ERC20Mock coin = new ERC20Mock("Coin", "COIN", 18);

        strandedAmount = bound(strandedAmount, 0, type(uint256).max / INFRASTRUCTURE_TAX_BPS);
        recoverAmount = bound(recoverAmount, 0, strandedAmount);

        uint256 recoveryTaxAmount = recoverAmount * INFRASTRUCTURE_TAX_BPS / FEE_DENOMINATOR;
        uint256 mevAmount = recoverAmount - recoveryTaxAmount;

        _sanitizeAddress(mev, new address[](0));
        _sanitizeAddress(to, new address[](0));

        coin.mint(address(weth), strandedAmount);

        vm.prank(mev);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(weth), ADDRESS_INFRASTRUCTURE_TAX, recoveryTaxAmount);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(weth), to, mevAmount);
        IWrappedNativeExtended(address(weth)).recoverStrandedTokens(TOKEN_STANDARD_ERC20, address(coin), to, tokenId, recoverAmount);

        assertEq(coin.balanceOf(ADDRESS_INFRASTRUCTURE_TAX), recoveryTaxAmount);
        assertEq(coin.balanceOf(to), mevAmount);
    }

    function testRecoverStrandedTokensERC721(address mev, address to, uint256 tokenId, uint256 amount) public {
        ERC721Mock token = new ERC721Mock();

        _sanitizeAddress(mev, new address[](0));
        _sanitizeAddress(to, new address[](0));

        token.mint(address(weth), tokenId);
        
        vm.prank(mev);
        IWrappedNativeExtended(address(weth)).recoverStrandedTokens(TOKEN_STANDARD_ERC721, address(token), to, tokenId, amount);

        assertTrue(token.ownerOf(tokenId) == to);
    }

    function testRecoverStrandedTokensRevertsWhenTokenStandardIsInvalid(uint256 tokenStandard, address token, address to, uint256 tokenId, uint256 amount) public {
        if (tokenStandard == TOKEN_STANDARD_ERC20 || tokenStandard == TOKEN_STANDARD_ERC721) {
            ++tokenStandard;
        }

        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).recoverStrandedTokens(tokenStandard, token, to, tokenId, amount);
    }

    function testRecoverStrandedTokensRevertsWhenTokenStandardIsValidAndTokenIsZero(address mev, address to, uint256 tokenId, uint256 amount) public {
        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).recoverStrandedTokens(TOKEN_STANDARD_ERC20, address(0), to, tokenId, amount);

        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).recoverStrandedTokens(TOKEN_STANDARD_ERC721, address(0), to, tokenId, amount);
    }

    function testRecoverStrandedTokensRevertsWhenExpectedTransferFunctionIsNotImplemented(uint256 tokenStandard, address token, address to, uint256 tokenId, uint256 amount) public {
        ContractMockRejectsNative token = new ContractMockRejectsNative();

        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).recoverStrandedTokens(TOKEN_STANDARD_ERC20, address(token), to, tokenId, amount);

        vm.expectRevert();
        IWrappedNativeExtended(address(weth)).recoverStrandedTokens(TOKEN_STANDARD_ERC721, address(token), to, tokenId, amount);
    }

    //=================================================
    //===================== Helpers ===================
    //=================================================

    function _sanitizeBadSelectorFallbackImplementation(bytes4 selector) private view returns (bytes4) {
        if (selector == SELECTOR_IS_NONCE_USED ||
            selector == SELECTOR_MASTER_NONCES ||
            selector == SELECTOR_TOTAL_SUPPLY ||
            selector == SELECTOR_DOMAIN_SEPARATOR_V4 ||
            selector == SELECTOR_NAME ||
            selector == SELECTOR_SYMBOL ||
            selector == SELECTOR_DECIMALS) {
            selector = bytes4(uint32(selector) + 1);
        }
        return selector;
    }

    function _sanitizeBadSelectorImplementedFunctions(bytes4 selector) private view returns (bytes4) {
        if (selector == weth.balanceOf.selector ||
            selector == weth.transfer.selector ||
            selector == weth.allowance.selector ||
            selector == weth.approve.selector ||
            selector == weth.transferFrom.selector ||
            selector == weth.deposit.selector ||
            selector == weth.withdraw.selector ||
            selector == IWrappedNativeExtended(address(weth)).depositTo.selector ||
            selector == IWrappedNativeExtended(address(weth)).withdrawToAccount.selector ||
            selector == IWrappedNativeExtended(address(weth)).withdrawSplit.selector ||
            selector == IWrappedNativeExtended(address(weth)).revokeMyOutstandingPermits.selector ||
            selector == IWrappedNativeExtended(address(weth)).revokeMyNonce.selector ||
            selector == IWrappedNativeExtended(address(weth)).permitTransfer.selector ||
            selector == IWrappedNativeExtended(address(weth)).doPermittedWithdraw.selector ||
            selector == IWrappedNativeExtended(address(weth)).recoverWNativeFromZeroAddress.selector ||
            selector == IWrappedNativeExtended(address(weth)).recoverStrandedTokens.selector) {
            selector = bytes4(uint32(selector) + 1);
        }
        return selector;
    }

    function _sanitizeAddress(address addr, address[] memory exclusionList) internal view {
        vm.assume(uint160(addr) > 0xFF);
        vm.assume(addr != address(0));
        vm.assume(addr != ADDRESS_INFRASTRUCTURE_TAX);
        vm.assume(addr != address(0x000000000000000000636F6e736F6c652e6c6f67));
        vm.assume(addr != address(0xDDc10602782af652bB913f7bdE1fD82981Db7dd9));
        vm.assume(addr != address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38));
        vm.assume(addr != address(weth));
        vm.assume(addr.code.length == 0);

        for (uint256 i = 0; i < exclusionList.length; ++i) {
            vm.assume(addr != exclusionList[i]);
        }
    }

    struct AddressAmount {
        address account;
        uint256 totalAmount;
    }

    function _aggregateAmountsByAddress(
        address[] memory toAccounts, 
        uint256[] memory amounts
    ) 
        public 
        pure 
        returns (uint256[] memory totalAmountsTo) 
    {
        require(toAccounts.length == amounts.length, "Input arrays must have the same length");

        totalAmountsTo = new uint256[](toAccounts.length);

        for (uint256 i = 0; i < toAccounts.length; i++) {
            address account = toAccounts[i];
            uint256 amount = amounts[i];

            for (uint256 j = 0; j < toAccounts.length; j++) {
                if (toAccounts[j] == account) {
                    totalAmountsTo[i] += amounts[j];
                }
            }
        }

        return totalAmountsTo;
    }

    function _computeExpectedWithdrawalSplits(
        uint256 amount,
        address convenienceFeeReceiver,
        uint256 convenienceFeeBps
    ) private pure returns (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) {
        
        if (convenienceFeeReceiver == address(0)) {
            convenienceFeeBps = 0;
        }

        unchecked {
            if (convenienceFeeBps > 9) {
                convenienceFee = amount * convenienceFeeBps / FEE_DENOMINATOR;
                convenienceFeeInfrastructure = convenienceFee * INFRASTRUCTURE_TAX_BPS / FEE_DENOMINATOR;
                convenienceFee -= convenienceFeeInfrastructure;
                userAmount = amount - convenienceFee - convenienceFeeInfrastructure;
            } else if (convenienceFeeBps > 0) {
                convenienceFeeInfrastructure = amount / FEE_DENOMINATOR;
                convenienceFee = amount * (convenienceFeeBps - ONE) / FEE_DENOMINATOR;
                userAmount = amount - convenienceFee - convenienceFeeInfrastructure;
            } else {
                convenienceFeeInfrastructure = amount / FEE_DENOMINATOR;
                userAmount = amount - convenienceFeeInfrastructure;
            }
        }
    }
}