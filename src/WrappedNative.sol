pragma solidity 0.8.26;

import "./Constants.sol";
import "./IRecoverTokens.sol";
import "./utils/EIP712.sol";
import "./utils/Math.sol";

contract WrappedNative is EIP712 {
    mapping (address => uint256)                    private _masterNonces;
    mapping (address => mapping (uint256 => uint256)) private _permitNonces;

    mapping (address => uint256)                    public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    constructor() EIP712(NAME, VERSION) {}

    /**
     * =================================================
     * == Deposit / Fallback Function Implementations ==
     * =================================================
     */

    fallback() external payable {
        if (msg.value > 0) {
            deposit();
        } else {
            if (msg.sig == SELECTOR_IS_NONCE_USED) { // isNonceUsed(address account, uint256 nonce)
                (address account, uint256 nonce) = abi.decode(msg.data[4:], (address,uint256));
                bool isUsed = ((_permitNonces[account][uint248(nonce >> 8)] >> uint8(nonce)) & ONE) == ONE;
                assembly {
                    mstore(0x00, isUsed)
                    return(0x00, 0x20)
                }
            } else if (msg.sig == SELECTOR_MASTER_NONCES) { // masterNonces(address account)
                assembly {
                    mstore(0x00, shr(0x60, shl(0x60, calldataload(0x04))))
                    mstore(0x20, _masterNonces.slot)
                    mstore(0x00, sload(keccak256(0x00, 0x40)))
                    return(0x00, 0x20)
                }
            } else if (msg.sig == SELECTOR_TOTAL_SUPPLY) { // totalSupply()
                assembly {
                    mstore(0x00, selfbalance())
                    return(0x00, 0x20)
                }
            } else if (msg.sig == SELECTOR_DOMAIN_SEPARATOR_V4) { // domainSeparatorV4()
                bytes32 domainSeparator = _domainSeparatorV4();
                assembly {
                    mstore(0x00, domainSeparator)
                    return(0x00, 0x20)
                }
            } else if (msg.sig == SELECTOR_NAME) { // name()
                bytes memory nameReturnValue = abi.encode(NAME);
                assembly {
                    return(add(nameReturnValue, 0x20), mload(nameReturnValue))
                }
            } else if (msg.sig == SELECTOR_SYMBOL) { // symbol()
                bytes memory symbolReturnValue = abi.encode(SYMBOL);
                assembly {
                    return(add(symbolReturnValue, 0x20), mload(symbolReturnValue))
                }
            } else if (msg.sig == SELECTOR_DECIMALS) { // decimals()
                assembly {
                    mstore(0x00, 0x12) // 18
                    return(0x00, 0x20)
                }
            } else {
                revert();
            }
        }
    }

    receive() external payable {
        deposit();
    }

    /**
     * =================================================
     * ========== Basic Deposits / Withdrawals =========
     * =================================================
     */

    function deposit() public payable {
        depositTo(msg.sender);
    }

    function depositTo(address to) public payable {
        assembly {
            mstore(0x00, to)
            mstore(0x20, balanceOf.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            sstore(balanceSlot, add(sload(balanceSlot), callvalue()))

            mstore(0x00, callvalue())
            log2(0x00, 0x20, DEPOSIT_EVENT_TOPIC_0, to)
        }
    }

    function withdraw(uint256 amount) public {
        withdrawToAccount(msg.sender, amount);
    }

    function withdrawToAccount(address to, uint256 amount) public {
        _withdrawFromAccount(msg.sender, to, amount);
    }

    function withdrawSplit(address[] calldata toAddresses, uint256[] calldata amounts) external {
        if (toAddresses.length != amounts.length || toAddresses.length == 0) {
            revert();
        }

        for (uint256 i = 0; i < toAddresses.length;) {
            withdrawToAccount(toAddresses[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * =================================================
     * ========== ERC-20 Approvals & Transfers =========
     * =================================================
     */

    function approve(address spender, uint256 amount) public payable returns (bool) {
        if (msg.value > 0) {
            deposit();
        }

        assembly {
            mstore(0x00, caller())
            mstore(0x20, allowance.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(0x00, spender)
            let allowanceSlot := keccak256(0x00, 0x40)

            sstore(allowanceSlot, amount)

            mstore(0x00, amount)
            log3(0x00, 0x20, APPROVAL_EVENT_TOPIC_0, caller(), spender)

            mstore(0x00, 0x01)
            return(0x00, 0x20)
        }
    }

    function transfer(address to, uint256 amount) public payable returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public payable
        returns (bool)
    {
        if (msg.value > 0) {
            deposit();
        }

        assembly {
            mstore(0x00, to)
            mstore(0x20, balanceOf.slot)
            let balanceSlotTo := keccak256(0x00, 0x40)
            sstore(balanceSlotTo, add(sload(balanceSlotTo), amount))
    
            mstore(0x00, from)
            let balanceSlotFrom := keccak256(0x00, 0x40)
            let balanceValFrom := sload(balanceSlotFrom)
            if lt(balanceValFrom, amount) {
                revert(0,0)
            }
            sstore(balanceSlotFrom, sub(balanceValFrom, amount))

            if iszero(eq(from, caller())) {
                mstore(0x20, allowance.slot)
                mstore(0x20, keccak256(0x00, 0x40))
                mstore(0x00, caller())
                let allowanceSlot := keccak256(0x00, 0x40)
                let allowanceVal := sload(allowanceSlot)

                if iszero(eq(allowanceVal, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)) {
                    if lt(allowanceVal, amount) {
                        revert(0,0)
                    }
                    sstore(allowanceSlot, sub(allowanceVal, amount))
                }
            }

            mstore(0x00, amount)
            log3(0x00, 0x20, TRANSFER_EVENT_TOPIC_0, from, to)

            mstore(0x00, 0x01)
            return(0x00, 0x20)
        }
    }

    /**
     * =================================================
     * ======= Permitted Transfers / Withdrawals =======
     * =================================================
     */

    function revokeMyOutstandingPermits() external {
        assembly {
            mstore(0x00, caller())
            mstore(0x20, _masterNonces.slot)
            let masterNonceSlot := keccak256(0x00, 0x40)
            let invalidatedNonce := sload(masterNonceSlot)
            sstore(masterNonceSlot, add(0x01, invalidatedNonce))
            log3(0x00, 0x00, MASTER_NONCE_INVALIDATED_EVENT_TOPIC_0, caller(), invalidatedNonce)
        }
    }

    function revokeMyNonce(uint256 nonce) external {
        _checkAndInvalidateNonce(msg.sender, nonce);
    }

    function permitTransfer(
        address from,
        address to,
        uint256 transferAmount,
        uint256 permitAmount,
        uint256 nonce,
        uint256 expiration,
        bytes calldata signedPermit
    ) external {
        if (block.timestamp > expiration ||
            transferAmount > permitAmount ||
            from == address(0) ||
            to == address(0)) {
            revert();
        }

        _checkAndInvalidateNonce(from, nonce);
        
        _verifyPermitSignature(
            from,
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_TYPEHASH,
                        msg.sender,
                        permitAmount,
                        nonce,
                        expiration,
                        _masterNonces[from]
                    )
                )
            ), 
            signedPermit
        );

        _balanceTransfer(from, to, transferAmount);
    }

    function doPermittedWithdraw(
        address from,
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 expiration,
        address convenienceFeeReceiver,
        uint256 convenienceFeeBps,
        bytes calldata signedPermit
    ) external {
        if (block.timestamp > expiration ||
            from == address(0) ||
            to == address(0)) {
            revert();
        }

        _checkAndInvalidateNonce(from, nonce);

        _verifyPermitSignature(
            from,
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        PERMIT_WITHDRAWAL_TYPEHASH,
                        msg.sender,
                        amount,
                        nonce,
                        expiration,
                        _masterNonces[from],
                        to,
                        convenienceFeeReceiver,
                        convenienceFeeBps
                    )
                )
            ), 
            signedPermit
        );

        (
            uint256 userAmount, 
            uint256 convenienceFee, 
            uint256 infrastructureFee
        ) = _computeWithdrawalSplits(amount, convenienceFeeReceiver, convenienceFeeBps);

        if (convenienceFeeReceiver != address(0) && convenienceFee > 0) {
            _balanceTransfer(from, convenienceFeeReceiver, convenienceFee);
        }

        if (infrastructureFee > 0) {
            _balanceTransfer(from, ADDRESS_INFRASTRUCTURE_TAX, infrastructureFee);
        }

        _withdrawFromAccount(from, to, userAmount);
    }

    /**
     * =================================================
     * ============ MEV-Based Asset Recovery ===========
     * =================================================
     */

    function recoverStrandedWNative(address from, address to, uint256 amount) external {
        if (from == ADDRESS_ZERO || from == ADDRESS_DEAD) {
            (
                uint256 recoveryTaxAmount, 
                uint256 mevAmount
            ) = _computeRecoverySplits(amount);
            _balanceTransfer(from, ADDRESS_INFRASTRUCTURE_TAX, recoveryTaxAmount);
            _balanceTransfer(from, to, mevAmount);
        } else {
            revert();
        }
    }

    function recoverStrandedTokens(uint256 tokenStandard, address token, address to, uint256 tokenId, uint256 amount) external {
        if (tokenStandard == 20) {
            (
                uint256 recoveryTaxAmount, 
                uint256 mevAmount
            ) = _computeRecoverySplits(amount);
            IRecoverTokens(token).transfer(ADDRESS_INFRASTRUCTURE_TAX, recoveryTaxAmount);
            IRecoverTokens(token).transfer(to, mevAmount);
        } else if (tokenStandard == 721) {
            IRecoverTokens(token).safeTransferFrom(address(this), to, tokenId);
        } else if (tokenStandard == 1155) {
            IRecoverTokens(token).safeTransferFrom(address(this), to, tokenId, amount, "");
        } else {
            revert();
        }
    }

    /**
     * =================================================
     * ========= Miscellaneous Helper Functions ========
     * =================================================
     */

    function _balanceTransfer(address from, address to, uint256 amount) private {
        assembly {
            mstore(0x00, to)
            mstore(0x20, balanceOf.slot)
            let balanceSlotTo := keccak256(0x00, 0x40)
            sstore(balanceSlotTo, add(sload(balanceSlotTo), amount))
    
            mstore(0x00, from)
            let balanceSlotFrom := keccak256(0x00, 0x40)
            let balanceValFrom := sload(balanceSlotFrom)
            if lt(balanceValFrom, amount) {
                revert(0,0)
            }
            sstore(balanceSlotFrom, sub(balanceValFrom, amount))

            mstore(0x00, amount)
            log3(0x00, 0x20, TRANSFER_EVENT_TOPIC_0, from, to)
        }
    }

    function _withdrawFromAccount(address from, address to, uint256 amount) private {
        assembly {
            mstore(0x00, from)
            mstore(0x20, balanceOf.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            let balanceVal := sload(balanceSlot)
            let updatedBalance := sub(balanceVal, amount)
            sstore(balanceSlot, updatedBalance)

            mstore(0x00, amount)
            log2(0x00, 0x20, WITHDRAWAL_EVENT_TOPIC_0, from)

            if or(gt(updatedBalance, balanceVal), iszero(call(gas(), to, amount, 0, 0, 0, 0))) {
                revert(0,0)
            }
        }
    }

    function _checkAndInvalidateNonce(address account, uint256 nonce) private {
        unchecked {
            if (uint256(_permitNonces[account][uint248(nonce >> 8)] ^= (ONE << uint8(nonce))) & 
                (ONE << uint8(nonce)) == ZERO) {
                revert();
            }
        }

        assembly {
            log3(0x00, 0x00, PERMIT_NONCE_INVALIDATED_EVENT_TOPIC_0, account, nonce)
        }
    }

    /**
     * =================================================
     * ============= Fee Split Calculations ============
     * =================================================
     */

    function _computeRecoverySplits(
        uint256 amount
    ) private pure returns (uint256 recoveryTaxAmount, uint256 mevAmount) {
        recoveryTaxAmount = amount * INFRASTRUCTURE_TAX_BPS / FEE_DENOMINATOR;
        mevAmount = amount - recoveryTaxAmount;
    }

    function _computeWithdrawalSplits(
        uint256 amount,
        address convenienceFeeReceiver,
        uint256 convenienceFeeBps
    ) private pure returns (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) {
        if (convenienceFeeReceiver != address(0)) {
            convenienceFee = amount * convenienceFeeBps / FEE_DENOMINATOR;
            convenienceFeeInfrastructure = convenienceFee * INFRASTRUCTURE_TAX_BPS / FEE_DENOMINATOR;
        }

        convenienceFeeInfrastructure = Math.max(convenienceFeeInfrastructure, amount / FEE_DENOMINATOR);
        if (convenienceFee >= convenienceFeeInfrastructure) {
            convenienceFee -= convenienceFeeInfrastructure;
        }

        userAmount = amount - convenienceFee - convenienceFeeInfrastructure;
    }

    /**
     * =================================================
     * ============ Signature Verification =============
     * =================================================
     */

    /**
     * @notice  Verifies a permit signature based on the bytes length of the signature provided.
     * 
     * @dev     Throws when -
     * @dev         The bytes signature length is 64 or 65 bytes AND
     * @dev         The ECDSA recovered signer is not the expectedSigner AND
     * @dev         The expectedSigner's code length is zero OR the expectedSigner does not return a valid EIP-1271 response
     * @dev 
     * @dev         OR
     * @dev
     * @dev         The bytes signature length is not 64 or 65 bytes AND
     * @dev         The expectedSigner's code length is zero OR the expectedSigner does not return a valid EIP-1271 response
     */
    function _verifyPermitSignature(
        address expectedSigner, 
        bytes32 digest, 
        bytes calldata signature
    ) private view {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // Divide the signature in r, s and v variables
            /// @solidity memory-safe-assembly
            assembly {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 32))
                v := byte(0, calldataload(add(signature.offset, 64)))
            }
            (bool isError, address signer) = _ecdsaRecover(digest, v, r, s);
            if (expectedSigner != signer || isError) {
                _verifyEIP1271Signature(expectedSigner, digest, signature);
            }
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // Divide the signature in r and vs variables
            /// @solidity memory-safe-assembly
            assembly {
                r := calldataload(signature.offset)
                vs := calldataload(add(signature.offset, 32))
            }
            (bool isError, address signer) = _ecdsaRecover(digest, r, vs);
            if (expectedSigner != signer || isError) {
                _verifyEIP1271Signature(expectedSigner, digest, signature);
            }
        } else {
            _verifyEIP1271Signature(expectedSigner, digest, signature);
        }
    }

    /**
     * @notice Verifies an EIP-1271 signature.
     * 
     * @dev    Throws when `signer` code length is zero OR the EIP-1271 call does not
     * @dev    return the correct magic value.
     * 
     * @param signer     The signer address to verify a signature with
     * @param hash       The hash digest to verify with the signer
     * @param signature  The signature to verify
     */
    function _verifyEIP1271Signature(address signer, bytes32 hash, bytes calldata signature) private view {
        if(signer.code.length == 0) {
            revert();
        }

        if (!_safeIsValidSignature(signer, hash, signature)) {
            revert();
        }
    }

    /**
     * @notice  Overload of the `_ecdsaRecover` function to unpack the `v` and `s` values
     * 
     * @param digest    The hash digest that was signed
     * @param r         The `r` value of the signature
     * @param vs        The packed `v` and `s` values of the signature
     * 
     * @return isError  True if the ECDSA function is provided invalid inputs
     * @return signer   The recovered address from ECDSA
     */
    function _ecdsaRecover(bytes32 digest, bytes32 r, bytes32 vs) private pure returns (bool isError, address signer) {
        unchecked {
            bytes32 s = vs & UPPER_BIT_MASK;
            uint8 v = uint8(uint256(vs >> 255)) + 27;

            (isError, signer) = _ecdsaRecover(digest, v, r, s);
        }
    }

    /**
     * @notice  Recovers the signer address using ECDSA
     * 
     * @dev     Does **NOT** revert if invalid input values are provided or `signer` is recovered as address(0)
     * @dev     Returns an `isError` value in those conditions that is handled upstream
     * 
     * @param digest    The hash digest that was signed
     * @param v         The `v` value of the signature
     * @param r         The `r` value of the signature
     * @param s         The `s` value of the signature
     * 
     * @return isError  True if the ECDSA function is provided invalid inputs
     * @return signer   The recovered address from ECDSA
     */
    function _ecdsaRecover(bytes32 digest, uint8 v, bytes32 r, bytes32 s) private pure returns (bool isError, address signer) {
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            // Invalid signature `s` value - return isError = true and signer = address(0) to check EIP-1271
            return (true, address(0));
        }

        signer = ecrecover(digest, v, r, s);
        isError = (signer == address(0));
    }

    /**
     * @notice A gas efficient, and fallback-safe way to call the isValidSignature function for EIP-1271.
     *
     * @param signer     The EIP-1271 signer to call to check for a valid signature.
     * @param hash       The hash digest to verify with the EIP-1271 signer.
     * @param signature  The supplied signature to verify.
     * 
     * @return isValid   True if the EIP-1271 signer returns the EIP-1271 magic value.
     */
    function _safeIsValidSignature(
        address signer,
        bytes32 hash,
        bytes calldata signature
    ) private view returns(bool isValid) {
        assembly {
            function _callIsValidSignature(_signer, _hash, _signatureOffset, _signatureLength) -> _isValid {
                let ptr := mload(0x40)
                // store isValidSignature(bytes32,bytes) selector
                mstore(ptr, hex"1626ba7e")
                // store bytes32 hash value in abi encoded location
                mstore(add(ptr, 0x04), _hash)
                // store abi encoded location of the bytes signature data
                mstore(add(ptr, 0x24), 0x40)
                // store bytes signature length
                mstore(add(ptr, 0x44), _signatureLength)
                // copy calldata bytes signature to memory
                calldatacopy(add(ptr, 0x64), _signatureOffset, _signatureLength)
                // calculate data length based on abi encoded data with rounded up signature length
                let dataLength := add(0x64, and(add(_signatureLength, 0x1F), not(0x1F)))
                // update free memory pointer
                mstore(0x40, add(ptr, dataLength))

                // static call _signer with abi encoded data
                // skip return data check if call failed or return data size is not at least 32 bytes
                if and(iszero(lt(returndatasize(), 0x20)), staticcall(gas(), _signer, ptr, dataLength, 0x00, 0x20)) {
                    // check if return data is equal to isValidSignature magic value
                    _isValid := eq(mload(0x00), hex"1626ba7e")
                    leave
                }
            }
            isValid := _callIsValidSignature(signer, hash, signature.offset, signature.length)
        }
    }
}