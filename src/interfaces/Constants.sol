// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

string constant VERSION = "1";
string constant NAME = "Wrapped Native";
string constant SYMBOL = "WNATIVE";
uint8 constant DECIMALS = 18;

bytes32 constant UPPER_BIT_MASK = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
uint256 constant ZERO = 0;
uint256 constant ONE = 1;
uint256 constant INFRASTRUCTURE_TAX_BPS = 10_00;
uint256 constant FEE_DENOMINATOR = 100_00;

address constant ADDRESS_INFRASTRUCTURE_TAX = address(0x0); // TODO

uint256 constant WITHDRAWAL_EVENT_TOPIC_0 = 0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65;
uint256 constant DEPOSIT_EVENT_TOPIC_0 = 0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c;
uint256 constant APPROVAL_EVENT_TOPIC_0 = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
uint256 constant TRANSFER_EVENT_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
uint256 constant PERMIT_NONCE_INVALIDATED_EVENT_TOPIC_0 = 0x8dc5a0b2e80f26187d38744e9559150e3bd6e06fccefbe737fd33411cfb15151;
uint256 constant MASTER_NONCE_INVALIDATED_EVENT_TOPIC_0 = 0x9614574d6542397172c19ba2bf4588434feeb977576e92b7b59b38242ab59609;

bytes32 constant PERMIT_TRANSFER_TYPEHASH =
    keccak256("PermitTransfer(address operator,uint256 amount,uint256 nonce,uint256 expiration,uint256 masterNonce)");

bytes32 constant PERMIT_WITHDRAWAL_TYPEHASH =
    keccak256("PermitWithdrawal(address operator,uint256 amount,uint256 nonce,uint256 expiration,uint256 masterNonce,address to,address convenienceFeeReceiver,uint256 convenienceFeeBps)");

bytes4 constant SELECTOR_IS_NONCE_USED = bytes4(keccak256("isNonceUsed(address,uint256)"));
bytes4 constant SELECTOR_MASTER_NONCES = bytes4(keccak256("masterNonces(address)"));
bytes4 constant SELECTOR_TOTAL_SUPPLY = bytes4(keccak256("totalSupply()"));
bytes4 constant SELECTOR_DOMAIN_SEPARATOR_V4 = bytes4(keccak256("domainSeparatorV4()"));
bytes4 constant SELECTOR_NAME = bytes4(keccak256("name()"));
bytes4 constant SELECTOR_SYMBOL = bytes4(keccak256("symbol()"));
bytes4 constant SELECTOR_DECIMALS = bytes4(keccak256("decimals()"));