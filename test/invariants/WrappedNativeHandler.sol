// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "forge-std/Base.sol";
import "forge-std/StdCheats.sol";
import "forge-std/StdUtils.sol";
import "forge-std/console.sol";
import "./AddressSet.sol";
import "src/interfaces/IWrappedNativeExtended.sol";
import "src/Constants.sol";
import "src/utils/MessageHashUtils.sol";
import "test/TestConstants.t.sol";

uint256 constant ETH_SUPPLY = 120_500_000 ether;

contract ForcePush {
    constructor(address dst) payable {
        selfdestruct(payable(dst));
    }
}

contract WrappedNativeHandler is CommonBase, StdCheats, StdUtils {
    using LibAddressSet for AddressSet;

    IWrappedNativeExtended public wnative;

    uint256 public ghost_depositSum;
    uint256 public ghost_withdrawSum;
    uint256 public ghost_forcePushSum;

    uint256 public ghost_zeroWithdrawals;
    uint256 public ghost_zeroPermittedWithdrawals;
    uint256 public ghost_zeroTransfers;
    uint256 public ghost_zeroTransferFroms;
    uint256 public ghost_zeroPermitTransfers;

    mapping(bytes32 => uint256) public calls;

    AddressSet internal _actors;
    address internal currentActor;
    address internal currentActorTo;

    modifier createActor() {
        if (msg.sender == address(0) ||
            msg.sender == address(wnative) ||
            msg.sender == address(this) ||
            msg.sender == address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38) ||
            msg.sender == address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D)) {
            assembly {
                return(0,0)
            }
        }

        currentActor = msg.sender;
        _actors.add(msg.sender);
        _;
    }

    modifier addActor(address actor) {
        if (actor == address(this) ||
            actor == address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38) ||
            actor == address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D)) {
            assembly {
                return(0,0)
            }
        }

        _actors.add(actor);
        _;
    }

    modifier createActorFromPK(uint160 pk) {
        if (pk == 0) {
            assembly {
                return(0,0)
            }
        }

        address actor = vm.addr(pk);
        if (actor == address(wnative) ||
            actor == address(this) ||
            actor == address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38) ||
            actor == address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D)) {
            assembly {
                return(0,0)
            }
        }

        _actors.add(actor);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors.rand(actorIndexSeed);
        if (currentActor == address(0) || currentActor == address(wnative)) {
            assembly {
                return(0,0)
            }
        }
        _;
    }

    modifier useActorTo(uint256 actorIndexSeed) {
        currentActorTo = _actors.rand(actorIndexSeed);
        if (currentActorTo == address(0) || currentActorTo == address(wnative)) {
            assembly {
                return(0,0)
            }
        }
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    constructor(IWrappedNativeExtended _wnative) {
        wnative = _wnative;
        deal(address(this), ETH_SUPPLY);
    }

    function deposit(uint256 amount) public createActor countCall("deposit") {
        amount = bound(amount, 0, address(this).balance);
        _pay(currentActor, amount);

        vm.prank(currentActor);
        wnative.deposit{value: amount}();

        ghost_depositSum += amount;
    }

    function depositTo(uint256 toSeed, uint256 amount) public createActor useActorTo(toSeed) countCall("depositTo") {
        amount = bound(amount, 0, address(this).balance);
        _pay(currentActor, amount);

        vm.prank(currentActor);
        wnative.depositTo{value: amount}(currentActorTo);

        ghost_depositSum += amount;
    }

    function transferWrappedNativeToZeroAddress(uint256 actorSeed, uint256 amount) public useActor(actorSeed) addActor(address(0)) countCall("transferWNativeToZeroAddress") {
        amount = bound(amount, 0, wnative.balanceOf(currentActor));
        if (amount == 0) ghost_zeroTransfers++;

        vm.prank(currentActor);
        wnative.transfer(address(0), amount);
    }

    function depositToZeroAddress(uint256 amount) public createActor addActor(address(0)) countCall("depositToZeroAddress") {
        amount = bound(amount, 0, address(this).balance);
        _pay(currentActor, amount);

        vm.prank(currentActor);
        wnative.depositTo{value: amount}(address(0));

        ghost_depositSum += amount;
    }

    function transferWrappedNativeToWrappedNativeAddress(uint256 actorSeed, uint256 amount) public useActor(actorSeed) addActor(address(wnative)) countCall("transferWNativeToTokenAddress") {
        amount = bound(amount, 0, wnative.balanceOf(currentActor));
        if (amount == 0) ghost_zeroTransfers++;

        vm.prank(currentActor);
        wnative.transfer(address(wnative), amount);
    }

    function withdraw(uint256 actorSeed, uint256 amount) public useActor(actorSeed) countCall("withdraw") {
        amount = bound(amount, 0, wnative.balanceOf(currentActor));
        if (amount == 0) ghost_zeroWithdrawals++;

        vm.startPrank(currentActor);
        wnative.withdraw(amount);
        _pay(address(this), amount);
        vm.stopPrank();

        ghost_withdrawSum += amount;
    }

    function withdrawToAccount(uint256 withdrawerActorSeed, uint256 toActorSeed, uint256 amount)
        public
        useActor(withdrawerActorSeed)
        useActorTo(toActorSeed)
        countCall("withdrawToAccount")
    {
        amount = bound(amount, 0, wnative.balanceOf(currentActor));
        if (amount == 0) ghost_zeroWithdrawals++;

        vm.prank(currentActor);
        wnative.withdrawToAccount(currentActorTo, amount);

        vm.startPrank(currentActorTo);
        _pay(address(this), amount);
        vm.stopPrank();

        ghost_withdrawSum += amount;
    }

    function withdrawSplit(
        uint256 withdrawerActorSeed, 
        uint256 toActorSeed0, 
        uint256 toActorSeed1,
        uint256 totalAmount)
        public
        useActor(withdrawerActorSeed)
        countCall("withdrawSplit")
    {
        totalAmount = bound(totalAmount, 0, wnative.balanceOf(currentActor));

        address[] memory toActors = new address[](2);
        toActors[0] = _actors.rand(toActorSeed0);
        toActors[1] = _actors.rand(toActorSeed1);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = totalAmount / 3;
        amounts[1] = totalAmount - amounts[0];

        if (totalAmount == 0) ghost_zeroWithdrawals++;

        vm.prank(currentActor);
        wnative.withdrawSplit(toActors, amounts);

        if (toActors[0] != address(wnative)) {
            vm.startPrank(toActors[0]);
            _pay(address(this), amounts[0]);
            vm.stopPrank();
            ghost_withdrawSum += amounts[0];
        }

        if (toActors[1] != address(wnative)) {
            vm.startPrank(toActors[1]);
            _pay(address(this), amounts[1]);
            vm.stopPrank();
            ghost_withdrawSum += amounts[1];
        }
    }

    function approve(uint256 actorSeed, uint256 spenderSeed, uint256 amount)
        public
        useActor(actorSeed)
        countCall("approve")
    {
        address spender = _actors.rand(spenderSeed);

        vm.prank(currentActor);
        wnative.approve(spender, amount);
    }

    function transfer(uint256 actorSeed, uint256 toSeed, uint256 amount)
        public
        useActor(actorSeed)
        countCall("transfer")
    {
        address to = _actors.rand(toSeed);

        amount = bound(amount, 0, wnative.balanceOf(currentActor));
        if (amount == 0) ghost_zeroTransfers++;

        vm.prank(currentActor);
        wnative.transfer(to, amount);
    }

    function transferAutoDeposit(uint256 actorSeed, uint256 toSeed, uint256 amount)
        public
        createActor()
        countCall("transfer")
    {
        address to = _actors.rand(toSeed);

        amount = bound(amount, 0, address(this).balance);
        _pay(currentActor, amount);
        if (amount == 0) ghost_zeroTransfers++;

        vm.prank(currentActor);
        wnative.transfer{value: amount}(to, amount);

        ghost_depositSum += amount;
    }

    function transferFrom(uint256 actorSeed, uint256 fromSeed, uint256 toSeed, bool _approve, uint256 amount)
        public
        useActor(actorSeed)
        countCall("transferFrom")
    {
        address from = _actors.rand(fromSeed);
        address to = _actors.rand(toSeed);

        amount = bound(amount, 0, wnative.balanceOf(from));

        if (_approve) {
            vm.prank(from);
            wnative.approve(currentActor, amount);
        } else {
            amount = bound(amount, 0, wnative.allowance(from, currentActor));
        }
        if (amount == 0) ghost_zeroTransferFroms++;

        vm.prank(currentActor);
        wnative.transferFrom(from, to, amount);
    }

    function transferFromAutoDeposit(uint256 actorSeed, uint256 fromSeed, uint256 toSeed, bool _approve, uint256 amount)
        public
        createActor()
        countCall("transferFrom")
    {
        address from = _actors.rand(fromSeed);
        address to = _actors.rand(toSeed);

        amount = bound(amount, 0, address(this).balance);

        if (_approve) {
            vm.prank(from);
            wnative.approve(currentActor, amount);
        } else {
            amount = bound(amount, 0, wnative.allowance(from, currentActor));
            amount = bound(amount, 0, address(this).balance);
        }
        _pay(currentActor, amount);
        if (amount == 0) ghost_zeroTransferFroms++;

        vm.prank(currentActor);
        wnative.transferFrom{value: amount}(from, to, amount);

        ghost_depositSum += amount;
    }

    function approveAutoDeposit(uint256 actorSeed, uint256 spenderSeed, uint256 amount)
        public
        createActor()
        countCall("approve")
    {
        address spender = _actors.rand(spenderSeed);

        amount = bound(amount, 0, address(this).balance);
        _pay(currentActor, amount);

        vm.prank(currentActor);
        wnative.approve{value: amount}(spender, amount);

        ghost_depositSum += amount;
    }

    function permitTransferAutoDeposit(
        uint160 fromPK,
        uint256 toSeed,
        uint256 transferAmount,
        uint256 permitAmount,
        uint256 nonce,
        uint256 expiration
    ) 
        public 
        createActor()
        createActorFromPK(fromPK)
        countCall("permitTransfer") 
    {
        address from = vm.addr(fromPK);
        address to = _actors.rand(toSeed);

        permitAmount = bound(permitAmount, 0, address(this).balance);
        transferAmount = bound(transferAmount, 0, permitAmount);
        nonce = _findNextAvailablePermitNonce(from, nonce);
        expiration = bound(expiration, block.timestamp, type(uint256).max);

        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                wnative.domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        currentActor,
                        permitAmount,
                        nonce,
                        expiration,
                        wnative.masterNonces(from)
                    )
                )
            );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromPK, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        if (transferAmount == 0) ghost_zeroPermitTransfers++;
        _pay(currentActor, permitAmount);

        vm.prank(currentActor);
        wnative.permitTransfer{value: permitAmount}(
            from, 
            to, 
            transferAmount, 
            permitAmount, 
            nonce, 
            expiration, 
            signedPermit);

        ghost_depositSum += permitAmount;
    }

    function doPermittedWithdrawal(
        uint160 fromPK,
        uint256 toSeed,
        uint256 depositAmount,
        uint256 withdrawalAmount,
        uint256 nonce,
        uint256 expiration,
        address convenienceFeeReceiver,
        uint256 convenienceFeeBps
    ) 
        public 
        createActor()
        createActorFromPK(fromPK)
        addActor(convenienceFeeReceiver)
        addActor(ADDRESS_INFRASTRUCTURE_TAX)
        countCall("doPermittedWithdrawal") 
    {
        address from = vm.addr(fromPK);
        address to = _actors.rand(toSeed);

        depositAmount = bound(depositAmount, 0, address(this).balance);
        depositAmount = bound(depositAmount, 0, type(uint240).max);
        withdrawalAmount = bound(withdrawalAmount, 0, depositAmount);
        nonce = _findNextAvailablePermitNonce(from, nonce);
        expiration = bound(expiration, block.timestamp, type(uint256).max);
        convenienceFeeBps = bound(convenienceFeeBps, 0, FEE_DENOMINATOR);

        bytes32 digest = 
            MessageHashUtils.toTypedDataHash(
                wnative.domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        currentActor,
                        withdrawalAmount,
                        nonce,
                        expiration,
                        wnative.masterNonces(from),
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            );
       
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fromPK, digest);
        bytes memory signedPermit = abi.encodePacked(r, s, uint8(v));

        if (withdrawalAmount == 0) ghost_zeroPermittedWithdrawals++;
        _pay(from, depositAmount);

        vm.prank(from);
        wnative.deposit{value: depositAmount}();

        vm.prank(currentActor);
        wnative.doPermittedWithdraw(
            from, 
            to, 
            withdrawalAmount, 
            nonce, 
            expiration, 
            convenienceFeeReceiver, 
            convenienceFeeBps, 
            signedPermit);

        ghost_depositSum += depositAmount;

        (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) = 
            _computeExpectedWithdrawalSplits(withdrawalAmount, convenienceFeeReceiver, convenienceFeeBps);

        if (to != address(wnative)) {
            vm.startPrank(to);
            _pay(address(this), userAmount);
            vm.stopPrank();
            ghost_withdrawSum += userAmount;
        }
    }

    function sendFallback(uint256 amount) public createActor countCall("sendFallback") {
        amount = bound(amount, 0, address(this).balance);
        _pay(currentActor, amount);

        vm.prank(currentActor);
        _pay(address(wnative), amount);

        ghost_depositSum += amount;
    }

    function forcePush(uint256 amount) public countCall("forcePush") {
        amount = bound(amount, 0, address(this).balance);
        new ForcePush{ value: amount }(address(wnative));
        ghost_forcePushSum += amount;
    }

    function revokeMasterNonce(uint256 actorSeed) public useActor(actorSeed) countCall("revokeMasterNonce") {
        vm.prank(currentActor);
        wnative.revokeMyOutstandingPermits();
    }

    function revokeMyNonce(uint256 actorSeed, uint256 nonce) public useActor(actorSeed) countCall("revokeMyNonce") {
        nonce = _findNextAvailablePermitNonce(currentActor, nonce);

        vm.prank(currentActor);
        wnative.revokeMyNonce(nonce);
    }

    function forEachActor(function(address) external func) public {
        return _actors.forEach(func);
    }

    function reduceActors(uint256 acc, function(uint256,address) external returns (uint256) func)
        public
        returns (uint256)
    {
        return _actors.reduce(acc, func);
    }

    function actors() external view returns (address[] memory) {
        return _actors.addrs;
    }

    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("deposit", calls["deposit"]);
        console.log("withdraw", calls["withdraw"]);
        console.log("sendFallback", calls["sendFallback"]);
        console.log("approve", calls["approve"]);
        console.log("transfer", calls["transfer"]);
        console.log("transferFrom", calls["transferFrom"]);
        console.log("forcePush", calls["forcePush"]);
        console.log("depositTo", calls["depositTo"]);
        console.log("withdrawToAccount", calls["withdrawToAccount"]);
        console.log("withdrawSplit", calls["withdrawSplit"]);
        console.log("transferWNativeToZeroAddress", calls["transferWNativeToZeroAddress"]);
        console.log("depositToZeroAddress", calls["depositToZeroAddress"]);
        console.log("transferWNativeToTokenAddress", calls["transferWNativeToTokenAddress"]);
        console.log("revokeMasterNonce", calls["revokeMasterNonce"]);
        console.log("revokeMyNonce", calls["revokeMyNonce"]);
        console.log("permitTransfer", calls["permitTransfer"]);
        console.log("doPermittedWithdrawal", calls["doPermittedWithdrawal"]);
        console.log("-------------------");

        console.log("Zero withdrawals:", ghost_zeroWithdrawals);
        console.log("Zero transferFroms:", ghost_zeroTransferFroms);
        console.log("Zero transfers:", ghost_zeroTransfers);
        console.log("Zero permitTransfers:", ghost_zeroPermitTransfers);
    }

    function _pay(address to, uint256 amount) internal {
        (bool s,) = to.call{value: amount}("");
        require(s, "pay() failed");
    }

    receive() external payable {}

    function _findNextAvailablePermitNonce(address account, uint256 nonce) internal view returns (uint256 availableNonce) {
        availableNonce = nonce;
        unchecked {
            while (wnative.isNonceUsed(account, availableNonce)) {
                availableNonce += uint256(keccak256(abi.encode(availableNonce)));
            }
        }
    }

    function _computeExpectedWithdrawalSplits(
        uint256 amount,
        address convenienceFeeReceiver,
        uint256 convenienceFeeBps
    ) internal pure returns (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) {
        
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