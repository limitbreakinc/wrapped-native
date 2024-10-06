// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./interfaces/Constants.sol";
import "./utils/EIP712.sol";
import "./utils/Math.sol";

/**
 * @title  WrappedNative
 * @author Limit Break, Inc.
 * @notice A contract that wraps native tokens (e.g. Ether) into an ERC-20 token.  Designed as a
 *         canonical replacement for WETH9 that can be deployed to a consistent, deterministic address on all chains.
 *
 * @notice WrappedNative features the following improvements over WETH9:
 *
 * @notice - **Deterministically Deployable By Anyone To A Consistent Address On Any Chain!**
 * @notice - **More Gas Efficient Operations Than WETH9!**
 * @notice - **`approve` and `transfer` functions are payable** - will auto-deposit when `msg.value > 0`.  This feature
 *           will allow a user to wrap and approve a protocol in a single action instead of two, improving UX and saving gas.
 * @notice - **`depositTo`** - allows a depositor to specify the address to give WNATIVE to.  
 *           Much more gas efficient for operations such as native refunds from protocols compared to `deposit + transfer`.
 * @notice - **`withdrawToAccount`** - allows a withdrawer to withdraw to a different address.
 * @notice - **`withdrawSplit`** - allows a withdrawer to withdraw and send native tokens to several addresses at once.
 * @notice - **Permit Functions** - allows for transfers and withdrawals to be approved to spenders/operators gaslessly using EIP-712 signatures.
 *           Permitted withdrawals allow gas sponsorship to unwrap wrapped native tokens on the user's behalf, for a small convenience fee specified by the app.
 *           This is useful when user has no native tokens on a new chain but they have received wrapped native tokens.
 */

contract WrappedNative is EIP712 {

    /// @dev Storage of user master nonces for permit processing.
    mapping (address => uint256) private _masterNonces;

    /// @dev Storage of permit nonces for permit processing.  Uses bitmaps for gas-efficient storage.
    mapping (address => mapping (uint256 => uint256)) private _permitNonces;

    /// @notice Stores the wrapped native token balance of each user.
    mapping (address => uint256) public  balanceOf;

    /// @notice Stores the wrapped native token allowance for each user/spender pair.
    mapping (address => mapping (address => uint)) public  allowance;

    constructor() EIP712(NAME, VERSION) {}

    //=================================================
    //== Deposit / Fallback Function Implementations ==
    //=================================================

    /**
     * @notice Fallback function to deposit funds into the contract, or to call various view functions.
     *         If the `msg.value` is greater than zero, the function will deposit the funds into the
     *         `msg.sender` account. If the `msg.value` is zero, the function will check the `msg.sig`
     *         to determine which view function is being called.  If a matching function selector is found
     *         the function will execute and return the appropriate value. If no matching function selector is found,
     *         the function will revert.
     *         
     * @notice The reason seldom-used view functions have been implemented via fallback is to save gas costs
     *         elsewhere in the contract in common operations that have a runtime gas cost.
     *
     * @notice The following function selectors are implemented via fallback:
     * 
     * @notice - **function isNonceUsed(address account, uint256 nonce) external view returns (bool)**
     * @notice - **function masterNonces(address account) external view returns (uint256)**
     * @notice - **function totalSupply() external view returns (uint256)**
     * @notice - **function domainSeparatorV4() external view returns (bytes32)**
     * @notice - **function name() external view returns (string)**
     * @notice - **function symbol() external view returns (string)**
     * @notice - **function decimals() external view returns (uint8)**
     *
     * @dev     Throws when `msg.value` == 0 and the `msg.sig` does not match any of the implemented view functions.
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

    /**
     * @notice Deposits `msg.value` funds into the `msg.sender` account, increasing their wrapped native token balance.
     * @notice This function is triggered when native funds are sent to this contract with no calldata.
     */
    receive() external payable {
        deposit();
    }

    //=================================================
    //========== Basic Deposits / Withdrawals =========
    //=================================================

    /**
     * @notice Deposits `msg.value` funds into the `msg.sender` account, increasing their wrapped native token balance.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. This contract's native token balance has increased by `msg.value`.
     * @dev    2. The `msg.sender`'s native token balance has decreased by `msg.value`.
     * @dev    3. The `msg.sender`'s wrapped native token balance has increased by `msg.value`.
     * @dev    4. A `Deposit` event has been emitted.  The `msg.sender` address is logged in the event.
     */
    function deposit() public payable {
        depositTo(msg.sender);
    }

    /**
     * @notice Deposits `msg.value` funds into specified user's account, increasing their wrapped native token balance.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. This contract's native token balance has increased by `msg.value`.
     * @dev    2. The `msg.sender`'s native token balance has decreased by `msg.value`.
     * @dev    3. The `to` account's wrapped native token balance has increased by `msg.value`.
     * @dev    4. A `Deposit` event has been emitted.  Caveat: The `to` address is logged in the event, not `msg.sender`.
     *
     * @param to  The address that receives wrapped native tokens.
     */
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

    /**
     * @notice Withdraws `amount` funds from the `msg.sender` account, decreasing their wrapped native token balance.
     *
     * @dev    Throws when the `msg.sender`'s wrapped native token balance is less than `amount` to withdraw.
     * @dev    Throws when the unwrapped native funds cannot be transferred to the `msg.sender` account.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. This contract's native token balance has decreased by `amount`.
     * @dev    2. The `msg.sender`'s wrapped native token balance has decreased by `amount`.
     * @dev    3. The `msg.sender`'s native token balance has increased by `amount`.
     * @dev    4. A `Withdrawal` event has been emitted.  The `msg.sender` address is logged in the event.
     *
     * @param amount  The amount of wrapped native tokens to withdraw.
     */
    function withdraw(uint256 amount) public {
        withdrawToAccount(msg.sender, amount);
    }

    /**
     * @notice Withdraws `amount` funds from the `msg.sender` account, decreasing their wrapped native token balance.
     *
     * @dev    Throws when the `msg.sender`'s wrapped native token balance is less than `amount` to withdraw.
     * @dev    Throws when the unwrapped native funds cannot be transferred to the `to` account.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. This contract's native token balance has decreased by `amount`.
     * @dev    2. The `msg.sender`'s wrapped native token balance has decreased by `amount`.
     * @dev    3. The `to` account's native token balance has increased by `amount`.
     * @dev    4. A `Withdrawal` event has been emitted.  Caveat: The `msg.sender` address is logged in the event, not `to`.
     *
     * @param to  The address that receives the unwrapped native tokens.
     * @param amount  The amount of wrapped native tokens to withdraw.
     */
    function withdrawToAccount(address to, uint256 amount) public {
        _withdrawFromAccount(msg.sender, to, amount);
    }

    /**
     * @notice Withdraws funds from the `msg.sender` and splits the funds between multiple receiver addresses.
     *
     * @dev    Throws when the `msg.sender`'s wrapped native token balance is less than the sum of `amounts` to withdraw.
     * @dev    Throws when the unwrapped native funds cannot be transferred to one or more of the receiver addresses.
     * @dev    Throws when the `toAddresses` and `amounts` arrays are not the same length.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. This contract's native token balance has decreased by the sum of `amounts`.
     * @dev    2. The `msg.sender`'s wrapped native token balance has decreased by the sum of `amounts`.
     * @dev    3. The receiver addresses' native token balances have increased by the corresponding amounts in `amounts`.
     * @dev    4. A `Withdrawal` event has been emitted for each receiver address.  Caveat: The `msg.sender` address is 
     *            logged in the events, not the receiver address.
     *
     * @param toAddresses  The addresses that receive the unwrapped native tokens.
     * @param amounts  The amounts of wrapped native tokens to withdraw for each receiver address.
     */
    function withdrawSplit(address[] calldata toAddresses, uint256[] calldata amounts) external {
        if (toAddresses.length != amounts.length) {
            revert();
        }

        for (uint256 i = 0; i < toAddresses.length;) {
            withdrawToAccount(toAddresses[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    //=================================================
    //========== ERC-20 Approvals & Transfers =========
    //=================================================

    /**
     * @notice Approves `spender` to spend/transfer `amount` of the `msg.sender`'s wrapped native tokens.
     *         When `amount` is set to `type(uint256).max`, the approval is unlimited.
     *
     * @notice Unlike a typical ERC-20 token, this function is payable, allowing for a `deposit` and approval to be
     *         executed simultaneously.  If `msg.value` is greater than zero, the function will deposit the funds
     *         into the `msg.sender` account before approving the `spender` to spend/transfer the funds.
     *         If `msg.value` is zero, the function will only approve the `spender` to spend/transfer the funds.
     *         This feature is intended to improve the UX of users using wrapped native tokens so that users don't have
     *         to perform two transactions to first deposit, then approve the spending of their tokens, saving gas in
     *         the process.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The `spender` is approved to spend/transfer `amount` of the `msg.sender`'s wrapped native tokens.
     * @dev    2. A `Approval` event has been emitted.  The `msg.sender` address, `spender` address, and `amount` of the 
     *            updated approval are logged in the event.
     * @dev    3. If `msg.value` is greater than zero, the `msg.sender`'s wrapped native token balance has increased by 
     *            `msg.value`.
     * @dev    4. If `msg.value` is greater than zero, a `Deposit` event has been emitted.  The `msg.sender` address is 
     *            logged in the event.
     *
     * @param spender  The address that is approved to spend/transfer the `msg.sender`'s wrapped native tokens.
     * @param amount   The amount of wrapped native tokens that the `spender` is approved to spend/transfer. Approved
     *                 spending is unlimited when this values is set to `type(uint256).max`.
     *
     * @return Always returns `true`.
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

    /**
     * @notice Transfers an `amount` of wrapped native tokens from the `msg.sender` to the `to` address.
     *
     * @notice If the `msg.value` is greater than zero, the function will deposit the funds into the `msg.sender` account
     *         before transferring the wrapped funds.  Otherwise, the function will only transfer the funds.
     *
     * @dev    Throws when the `msg.sender` has an insufficient balance to transfer `amount` of wrapped native tokens.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. When `msg.value` is greater than zero, this contract's native token balance has increased by `msg.value`.
     * @dev    2. When `msg.value` is greater than zero, the `msg.sender`'s native token balance has decreased by `msg.value`.
     * @dev    3. When `msg.value` is greater than zero, the `msg.sender`'s wrapped native token balance has increased by `msg.value`.
     * @dev    4. When `msg.value` is greater than zero, a `Deposit` event has been emitted.  The `msg.sender` address is logged in the event.
     * @dev    5. The `amount` of wrapped native tokens has been transferred from the `msg.sender` account to the `to` account.
     * @dev    6. A `Transfer` event has been emitted.  The `msg.sender` address, `to` address, and `amount` are logged in the event.
     *
     * @param to  The address that receives the wrapped native tokens.
     * @param amount  The amount of wrapped native tokens to transfer.
     *
     * @return Always returns `true`.
     */
    function transfer(address to, uint256 amount) public payable returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    /**
     * @notice Transfers an `amount` of wrapped native tokens from the `from` to the `to` address.
     *
     * @notice If the `msg.value` is greater than zero, the function will deposit the funds into the `from` account
     *         before transferring the wrapped funds.  Otherwise, the function will only transfer the funds.
     * @notice **As a reminder, the `msg.sender`'s native tokens will be deposited and the `from` (not the `msg.sender`) 
     *         address will be credited before the transfer.  Integrating spender/operator protocols MUST be aware that 
     *         deposits made during transfers will not credit their own account.**
     *
     * @dev    Throws when the `from` account has an insufficient balance to transfer `amount` of wrapped native tokens.
     * @dev    Throws when the `msg.sender` is not the `from` address, and the `msg.sender` has not been approved
     *         by `from` for an allowance greater than or equal to `amount`.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. When `msg.value` is greater than zero, this contract's native token balance has increased by `msg.value`.
     * @dev    2. When `msg.value` is greater than zero, the `msg.sender`'s native token balance has decreased by `msg.value`.
     * @dev    3. When `msg.value` is greater than zero, the `from` account's wrapped native token balance has increased by `msg.value`.
     * @dev    4. When `msg.value` is greater than zero, a `Deposit` event has been emitted.  The `from` address is logged in the event.
     * @dev    5. The `amount` of wrapped native tokens has been transferred from the `from` account to the `to` account.
     * @dev    6. A `Transfer` event has been emitted.  The `from` address, `to` address, and `amount` are logged in the event.
     *
     * @param from  The address that transfers the wrapped native tokens.
     * @param to    The address that receives the wrapped native tokens.
     * @param amount  The amount of wrapped native tokens to transfer.
     *
     * @return Always returns `true`.
     */
    function transferFrom(address from, address to, uint256 amount) public payable returns (bool) {
        if (msg.value > 0) {
            depositTo(from);
        }

        assembly {
            mstore(0x00, from)
            mstore(0x20, balanceOf.slot)
            let balanceSlotFrom := keccak256(0x00, 0x40)
            let balanceValFrom := sload(balanceSlotFrom)
            if lt(balanceValFrom, amount) {
                revert(0,0)
            }
            sstore(balanceSlotFrom, sub(balanceValFrom, amount))

            mstore(0x00, to)
            let balanceSlotTo := keccak256(0x00, 0x40)
            sstore(balanceSlotTo, add(sload(balanceSlotTo), amount))

            if iszero(eq(from, caller())) {
                mstore(0x00, from)
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

    //=================================================
    //======= Permitted Transfers / Withdrawals =======
    //=================================================

    /**
     * @notice Allows the `msg.sender` to revoke/cancel all prior permitted transfer and withdrawal signatures.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The `msg.sender`'s master nonce has been incremented by `1` in contract storage, rendering all signed
     *            permits using the prior master nonce unusable.
     * @dev    2. A `MasterNonceInvalidated` event has been emitted.
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

    /**
     * @notice Allows the `msg.sender` to revoke/cancel a single, previously signed permitted transfer or withdrawal 
     *         signature by specifying the nonce of the individual permit.
     *
     * @dev    Throws when the `msg.sender` has already revoked the permit nonce.
     * @dev    Throws when the permit nonce was already used successfully.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The specified `nonce` for the `msg.sender` has been revoked and can
     *            no longer be used to execute a permitted transfer or withdrawal.
     * @dev    2. A `PermitNonceInvalidated` event has been emitted.
     *
     * @param  nonce The nonce that was signed in the permitted transfer or withdrawal.
     */
    function revokeMyNonce(uint256 nonce) external {
        _checkAndInvalidateNonce(msg.sender, nonce);
    }

    /**
     * @notice Allows a spender/operator to transfer wrapped native tokens from the `from` account to the `to` account
     *         using a gasless signature from the `from` account so that the `from` account does not need to pay gas
     *         to set an on-chain allowance.
     *
     * @notice If the `msg.value` is greater than zero, the function will deposit the funds into the `from` account
     *         before transferring the wrapped funds.  Otherwise, the function will only transfer the funds.
     * @notice **As a reminder, the `msg.sender`'s native tokens will be deposited and the `from` (not the `msg.sender`) 
     *         address will be credited before the transfer.  Integrating spender/operator protocols MUST be aware that 
     *         deposits made during transfers will not credit their own account.**
     *
     * @dev    Throws when the `from` account is the zero address.
     * @dev    Throws when the `msg.sender` does not match the operator/spender from the signed transfer permit.
     * @dev    Throws when the permitAmount does not match the signed transfer permit. 
     * @dev    Throws when the nonce does not match the signed transfer permit.
     * @dev    Throws when the expiration does not match the signed transfer permit.
     * @dev    Throws when the permit has expired.
     * @dev    Throws when the requested transfer amount exceeds the maximum permitted transfer amount. 
     * @dev    Throws when the permit nonce has already been used or revoked/cancelled.
     * @dev    Throws when the master nonce has been revoked/cancelled since the permit was signed.
     * @dev    Throws when the permit signature is invalid, or was not signed by the `from` account.
     * @dev    Throws when the `from` account has an insufficient balance to transfer `transferAmount` of wrapped native tokens.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. When `msg.value` is greater than zero, this contract's native token balance has increased by `msg.value`.
     * @dev    2. When `msg.value` is greater than zero, the `msg.sender`'s native token balance has decreased by `msg.value`.
     * @dev    3. When `msg.value` is greater than zero, the `from` account's wrapped native token balance has increased by `msg.value`.
     * @dev    4. When `msg.value` is greater than zero, a `Deposit` event has been emitted.  The `from` address is logged in the event.
     * @dev    5. `nonce` for `from` account is invalidated.
     * @dev    6. A `PermitNonceInvalidated` event has been emitted.
     * @dev    7. The `transferAmount` of wrapped native tokens has been transferred from the `from` account to the `to` account.
     * @dev    8. A `Transfer` event has been emitted.  The `from` address, `to` address, and `transferAmount` are logged in the event.
     *
     * @param from  The address that transfers the wrapped native tokens.
     * @param to    The address that receives the wrapped native tokens.
     * @param transferAmount  The amount of wrapped native tokens to transfer.
     * @param permitAmount  The maximum amount of wrapped native tokens that can be transferred, signed in permit.
     * @param nonce  The nonce, signed in permit.
     * @param expiration  The expiration timestamp, signed in permit.
     * @param signedPermit  The signature of the permit.
     */
    function permitTransfer(
        address from,
        address to,
        uint256 transferAmount,
        uint256 permitAmount,
        uint256 nonce,
        uint256 expiration,
        bytes calldata signedPermit
    ) external payable {
        if (msg.value > 0) {
            depositTo(from);
        }

        if (block.timestamp > expiration ||
            transferAmount > permitAmount ||
            from == address(0)) {
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

    /**
     * @notice Allows a spender/operator to withdraw wrapped native tokens from the `from` account to the `to` account
     *         using a gasless signature signed by the `from` account to prove authorization of the withdrawal.
     *
     * @dev    Throws when the `from` account is the zero address.
     * @dev    Throws when the `msg.sender` does not match the operator/spender from the signed withdrawal permit.
     * @dev    Throws when the permit has expired.
     * @dev    Throws when the amount does not match the signed withdrawal permit. 
     * @dev    Throws when the nonce does not match the signed withdrawal permit.
     * @dev    Throws when the expiration does not match the signed withdrawal permit.
     * @dev    Throws when the convenience fee reciever and fee does not match the signed withdrawal permit.
     * @dev    Throws when the `to` address does not match the signed withdrawal permit.
     * @dev    Throws when the permit nonce has already been used or revoked/cancelled.
     * @dev    Throws when the master nonce has been revoked/cancelled since the permit was signed.
     * @dev    Throws when the permit signature is invalid, or was not signed by the `from` account.
     * @dev    Throws when the `from` account has an insufficient balance to transfer `transferAmount` of wrapped native tokens.
     *
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. This contract's native token balance has decreased by `amount`, less convenience and infrastructure
     *            fees that remain wrapped.
     * @dev    2. The `from` account's wrapped native token balance has decreased by `amount`.
     * @dev    3. The `to` account's native token balance has increased by `amount`, less convenience and/or infrastructure fees.
     * @dev    4. The `convenienceFeeReceiver` account's wrapped native token balance has increased by the convenience fee.
     * @dev    5. The infrastructure tax account's wrapped native token balance has increased by the infrastructure fee.
     * @dev    6. `nonce` for `from` account is invalidated.
     * @dev    7. A `PermitNonceInvalidated` event has been emitted.
     * @dev    8. A `Withdrawal` event has been emitted.  Caveat: The `from` address is logged in the event, not `to` or `msg.sender`.
     *
     * @param from  The address that from which funds are withdrawn.
     * @param to  The address that receives the withdrawn funds.
     * @param amount  The amount of wrapped native tokens to withdraw.
     * @param nonce  The nonce, signed in permit.
     * @param expiration  The expiration timestamp, signed in permit.
     * @param convenienceFeeReceiver  The address that receives the convenience fee.
     * @param convenienceFeeBps  The basis points of the convenience fee.
     * @param signedPermit  The signature of the permit.
     */
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
            from == address(0)) {
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

        if (convenienceFee > 0) {
            _balanceTransfer(from, convenienceFeeReceiver, convenienceFee);
        }

        if (infrastructureFee > 0) {
            _balanceTransfer(from, ADDRESS_INFRASTRUCTURE_TAX, infrastructureFee);
        }

        _withdrawFromAccount(from, to, userAmount);
    }

    //=================================================
    //========= Miscellaneous Helper Functions ========
    //=================================================

    /**
     * @dev Helper function that transfers wrapped native token balance between accounts.
     *
     * @dev Throws when the `from` account has an insufficient balance to transfer `amount` of wrapped native tokens.
     *
     * @param from  The address from which the wrapped native tokens is transferred.
     * @param to  The address to which the wrapped native tokens are transferred.
     * @param amount  The amount of wrapped native tokens to transfer.
     */
    function _balanceTransfer(address from, address to, uint256 amount) private {
        assembly {
            mstore(0x00, from)
            mstore(0x20, balanceOf.slot)
            let balanceSlotFrom := keccak256(0x00, 0x40)
            let balanceValFrom := sload(balanceSlotFrom)
            if lt(balanceValFrom, amount) {
                revert(0,0)
            }
            sstore(balanceSlotFrom, sub(balanceValFrom, amount))

            mstore(0x00, to)
            let balanceSlotTo := keccak256(0x00, 0x40)
            sstore(balanceSlotTo, add(sload(balanceSlotTo), amount))

            mstore(0x00, amount)
            log3(0x00, 0x20, TRANSFER_EVENT_TOPIC_0, from, to)
        }
    }

    /**
     * @dev Helper function that withdraws wrapped native tokens from an account to another account.
     *
     * @dev Throws when the `from` account has an insufficient balance to transfer `amount` of wrapped native tokens.
     * @dev Throws when the unwrapped native funds cannot be transferred to the `to` account.
     *
     * @param from  The address from which the wrapped native tokens are withdrawn.
     * @param to  The address to which the native tokens are transferred.
     * @param amount  The amount of wrapped native tokens to withdraw.
     */
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

    /**
     * @dev Helper function that checks and invalidates a permit nonce.
     * 
     * @dev Throws when the permit nonce has already been used or revoked/cancelled.
     * 
     * @param account  The account that signed the permit.
     * @param nonce  The nonce that was signed in the permit.
     */
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

    //=================================================
    //============= Fee Split Calculations ============
    //=================================================

    /**
     * @dev Helper function that computes the withdrawal fee split amounts.
     *
     * @param amount  The amount of wrapped native tokens to split.
     * @param convenienceFeeReceiver  The address that receives the convenience fee.
     * @param convenienceFeeBps  The basis points of the convenience fee.
     */
    function _computeWithdrawalSplits(
        uint256 amount,
        address convenienceFeeReceiver,
        uint256 convenienceFeeBps
    ) private pure returns (uint256 userAmount, uint256 convenienceFee, uint256 convenienceFeeInfrastructure) {
        if (convenienceFeeBps > FEE_DENOMINATOR) {
            revert();
        }

        if (amount > type(uint240).max) {
            revert();
        }

        if (convenienceFeeReceiver == address(0)) {
            convenienceFeeBps = 0;
        }

        unchecked {
            if (convenienceFeeBps > INFRASTRUCTURE_TAX_THRESHOLD) {
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

    //=================================================
    //============ Signature Verification =============
    //=================================================

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