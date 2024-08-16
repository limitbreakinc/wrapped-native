pragma solidity 0.8.26;

import "./IWrappedNative.sol";

interface IWrappedNativeExtended is IWrappedNative {
    // Wrapped Native Permit Specific
    event PermitNonceInvalidated(address indexed account,uint256 indexed nonce);
    event MasterNonceInvalidated(address indexed account, uint256 indexed nonce);

    // Enhancements for Deposits and Withdrawals
    function depositTo(address to) external payable;
    function withdrawToAccount(address to, uint256 amount) external;
    function withdrawSplit(address[] calldata toAddresses, uint256[] calldata amounts) external;

    // Permit Processing
    function domainSeparatorV4() external view returns (bytes32);

    function isNonceUsed(address account, uint256 nonce) external view returns (bool);
    function masterNonces(address account) external view returns (uint256);

    function revokeMyOutstandingPermits() external;
    function revokeMyNonce(uint256 nonce) external;

    function permitTransfer(
        address from,
        address to,
        uint256 transferAmount,
        uint256 permitAmount,
        uint256 nonce,
        uint256 expiration,
        bytes calldata signedPermit
    ) external payable;

    function doPermittedWithdraw(
        address from,
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 expiration,
        address convenienceFeeReceiver,
        uint256 convenienceFeeBps,
        bytes calldata signedPermit
    ) external;

    // MEV-Based Asset Recovery
    function recoverWNativeFromZeroAddress(address to, uint256 amount) external;
    function recoverStrandedTokens(
        uint256 tokenStandard, 
        address token, 
        address to, 
        uint256 tokenId, 
        uint256 amount
    ) external;
}