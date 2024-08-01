pragma solidity 0.8.26;

interface IRecoverTokens {
    function transfer(address /*_to*/, uint256 /*_value*/) external returns (bool);
    function safeTransferFrom(address /*_from*/, address /*_to*/, uint256 /*_tokenId*/) external;
    function safeTransferFrom(address /*_from*/, address /*_to*/, uint256 /*_id*/, uint256 /*_value*/, bytes calldata /*_data*/) external;
}
