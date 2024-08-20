// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRecoverTokens {
    function transfer(address /*_to*/, uint256 /*_value*/) external returns (bool);
    function safeTransferFrom(address /*_from*/, address /*_to*/, uint256 /*_tokenId*/) external;
}
