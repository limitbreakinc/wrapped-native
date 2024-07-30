pragma solidity 0.8.26;

interface IRecoverTokens {
    function transfer(address /*_to*/, uint256 /*_value*/) external returns (bool);
    function transferFrom(address /*_from*/, address /*_to*/, uint256 /*_tokenId*/) external;
    function safeTransferFrom(address /*_from*/, address /*_to*/, uint256 /*_id*/, uint256 /*_value*/, bytes calldata /*_data*/) external;
}

contract WrappedNative {
    string private constant NAME = "Wrapped Native";
    string private constant SYMBOL = "WNATIVE";
    uint8 private constant DECIMALS = 18;

    uint256 private constant WITHDRAWAL_EVENT_TOPIC_0 = 0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65;
    uint256 private constant DEPOSIT_EVENT_TOPIC_0 = 0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c;
    uint256 private constant APPROVAL_EVENT_TOPIC_0 = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
    uint256 private constant TRANSFER_EVENT_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    address private constant RECOVERY_TAX_ADDRESS = address(0x0); // TODO
    uint256 private constant RECOVERY_TAX_BPS = 5_000;
    uint256 private constant RECOVERY_TAX_DENOMINATOR = 10_000;

    event  Approval(address indexed src, address indexed guy, uint256 wad);
    event  Transfer(address indexed src, address indexed dst, uint256 wad);
    event  Deposit(address indexed dst, uint256 wad);
    event  Withdrawal(address indexed src, uint256 wad);

    mapping (address => uint256)                    public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    fallback() external payable {
        if (msg.value > 0) {
            depositFor(msg.sender);
        } else {
            if (msg.sig == 0x18160ddd) { // totalSupply()
                assembly {
                    mstore(0x00, selfbalance())
                    return(0x00, 0x20)
                }
            } else if (msg.sig == 0x06fdde03) { // name()
                bytes memory nameReturnValue = abi.encode(NAME);
                assembly {
                    return(add(nameReturnValue, 0x20), mload(nameReturnValue))
                }
            } else if (msg.sig == 0x95d89b41) { // symbol()
                bytes memory symbolReturnValue = abi.encode(SYMBOL);
                assembly {
                    return(add(symbolReturnValue, 0x20), mload(symbolReturnValue))
                }
            } else if (msg.sig == 0x313ce567) { // decimals()
                assembly {
                    mstore(0x00, 0x12) // 18
                    return(0x00, 0x20)
                }
            }
        }
    }

    receive() external payable {
        depositFor(msg.sender);
    }

    function deposit() public payable {
        depositFor(msg.sender);
    }

    function depositFor(address dst) public payable {
        assembly {
            mstore(0x00, dst)
            mstore(0x20, balanceOf.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            sstore(balanceSlot, add(sload(balanceSlot), callvalue()))

            mstore(0x00, callvalue())
            log2(0x00, 0x20, DEPOSIT_EVENT_TOPIC_0, dst)
        }
    }

    function withdraw(uint256 wad) public {
        withdrawForADestinationWallet(msg.sender, wad);
    }

    function withdrawSplit(address[] calldata toAddresses, uint256[] calldata amounts) external {
        if (toAddresses.length != amounts.length || toAddresses.length == 0) {
            revert();
        }

        for (uint256 i = 0; i < toAddresses.length;) {
            withdrawForADestinationWallet(toAddresses[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function withdrawForADestinationWallet(address to, uint256 wad) public {
        assembly {
            mstore(0x00, caller())
            mstore(0x20, balanceOf.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            let balanceVal := sload(balanceSlot)
            let updatedBalance := sub(balanceVal, wad)
            sstore(balanceSlot, updatedBalance)

            mstore(0x00, wad)
            log2(0x00, 0x20, WITHDRAWAL_EVENT_TOPIC_0, caller())

            if or(gt(updatedBalance, balanceVal), iszero(call(gas(), to, wad, 0, 0, 0, 0))) {
                revert(0,0)
            }
        }
    }

    function approve(address guy, uint256 wad) public payable returns (bool) {
        if (msg.value > 0) {
            deposit();
        }

        assembly {
            mstore(0x00, caller())
            mstore(0x20, allowance.slot)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(0x00, guy)
            let allowanceSlot := keccak256(0x00, 0x40)

            sstore(allowanceSlot, wad)

            mstore(0x00, wad)
            log3(0x00, 0x20, APPROVAL_EVENT_TOPIC_0, caller(), guy)

            mstore(0x00, 0x01)
            return(0x00, 0x20)
        }
    }

    function transfer(address dst, uint256 wad) public payable returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad)
        public payable
        returns (bool)
    {
        if (msg.value > 0) {
            deposit();
        }

        assembly {
            mstore(0x00, dst)
            mstore(0x20, balanceOf.slot)
            let balanceSlotDst := keccak256(0x00, 0x40)
            sstore(balanceSlotDst, add(sload(balanceSlotDst), wad))
    
            mstore(0x00, src)
            let balanceSlotSrc := keccak256(0x00, 0x40)
            let balanceValSrc := sload(balanceSlotSrc)
            if lt(balanceValSrc, wad) {
                revert(0,0)
            }
            sstore(balanceSlotSrc, sub(balanceValSrc, wad))

            if iszero(eq(src, caller())) {
                mstore(0x20, allowance.slot)
                mstore(0x20, keccak256(0x00, 0x40))
                mstore(0x00, caller())
                let allowanceSlot := keccak256(0x00, 0x40)
                let allowanceVal := sload(allowanceSlot)

                if iszero(eq(allowanceVal, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)) {
                    if lt(allowanceVal, wad) {
                        revert(0,0)
                    }
                    sstore(allowanceSlot, sub(allowanceVal, wad))
                }
            }

            mstore(0x00, wad)
            log3(0x00, 0x20, TRANSFER_EVENT_TOPIC_0, src, dst)

            mstore(0x00, 0x01)
            return(0x00, 0x20)
        }
    }

    function recoverStrandedTokens(uint256 tokenStandard, address token, address to, uint256 tokenId, uint256 amount) external {
        if (tokenStandard == 20) {
            uint256 recoveryTaxAmount = amount * RECOVERY_TAX_BPS / RECOVERY_TAX_DENOMINATOR;
            uint256 mevAmount = amount - recoveryTaxAmount;
            IRecoverTokens(token).transfer(RECOVERY_TAX_ADDRESS, recoveryTaxAmount);
            IRecoverTokens(token).transfer(to, mevAmount);
        } else if (tokenStandard == 721) {
            IRecoverTokens(token).transferFrom(address(this), to, tokenId);
        } else if (tokenStandard == 1155) {
            IRecoverTokens(token).safeTransferFrom(address(this), to, tokenId, amount, "");
        } else {
            revert();
        }
    }
}