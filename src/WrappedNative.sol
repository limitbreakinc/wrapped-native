pragma solidity 0.8.26;

contract WrappedNative {
    string public name     = "Wrapped Native";
    string public symbol   = "WNATIVE";
    uint8  public decimals = 18;

    uint256 private constant WITHDRAWAL_EVENT_TOPIC_0 = 0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65;
    uint256 private constant DEPOSIT_EVENT_TOPIC_0 = 0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c;
    uint256 private constant APPROVAL_EVENT_TOPIC_0 = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
    uint256 private constant TRANSFER_EVENT_TOPIC_0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    event  Approval(address indexed src, address indexed guy, uint256 wad);
    event  Transfer(address indexed src, address indexed dst, uint256 wad);
    event  Deposit(address indexed dst, uint256 wad);
    event  Withdrawal(address indexed src, uint256 wad);

    mapping (address => uint256)                    public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    fallback() external payable {
        deposit();
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        assembly {
            mstore(0x00, caller())
            mstore(0x20, balanceOf.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            sstore(balanceSlot, add(sload(balanceSlot), callvalue()))

            mstore(0x00, callvalue())
            log2(0x00, 0x20, DEPOSIT_EVENT_TOPIC_0, caller())
        }
    }
    function withdraw(uint256 wad) public {
        assembly {
            mstore(0x00, caller())
            mstore(0x20, balanceOf.slot)
            let balanceSlot := keccak256(0x00, 0x40)

            let balanceVal := sload(balanceSlot)
            let updatedBalance := sub(balanceVal, wad)
            sstore(balanceSlot, updatedBalance)

            mstore(0x00, wad)
            log2(0x00, 0x20, WITHDRAWAL_EVENT_TOPIC_0, caller())

            if or(gt(updatedBalance, balanceVal), iszero(call(gas(), caller(), wad, 0, 0, 0, 0))) {
                revert(0,0)
            }
        }
    }

    function totalSupply() public view returns (uint256) {
        assembly {
            mstore(0x00, selfbalance())
            return(0x00, 0x20)
        }
    }


    function approve(address guy, uint256 wad) public returns (bool) {
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

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
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
}