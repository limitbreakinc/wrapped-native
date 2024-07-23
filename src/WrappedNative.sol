pragma solidity 0.8.17;

contract WrappedNative {
    string public name     = "Wrapped Native";
    string public symbol   = "WNATIVE";
    uint8  public decimals = 18;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    fallback() external payable {
        deposit();
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        unchecked {
            balanceOf[msg.sender] += msg.value;
        }
        
        emit Deposit(msg.sender, msg.value);
    }
    function withdraw(uint wad) public {
//        uint256 balance = balanceOf[msg.sender];
//        unchecked {
//            uint256 updatedBalance = balance - wad;
//            if (updatedBalance > balance) {
//                revert();
//            }
//            balanceOf[msg.sender] = updatedBalance;
//        }
//
//        bool success;
//
//        assembly {
//            // Transfer the ETH and store if it succeeded or not.
//            success := call(gas(), caller(), wad, 0, 0, 0, 0)
//        }
//
//        if (!success) {
//            revert();
//        }
//
//        emit Withdrawal(msg.sender, wad);

//        require(balanceOf[msg.sender] >= wad);
//        balanceOf[msg.sender] -= wad;
//        payable(msg.sender).transfer(wad);
//        emit Withdrawal(msg.sender, wad);
        
        uint256 callerBalance = balanceOf[msg.sender];
        if (callerBalance < wad) {
            revert();
        }
        unchecked {
            balanceOf[msg.sender] = callerBalance - wad;
        }
        
        // Version 1
        //payable(msg.sender).transfer(wad);

        // Version 2
        //assembly {
        //    let success := call(gas(), caller(), wad, 0, 0, 0, 0)
        //    if iszero(success) {
        //        revert(0, 0)
        //    }
        //}

        // Version 3
        //(bool s,) = msg.sender.call{value: wad}("");
        //if (!s) {
        //    revert();
        //}

        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}