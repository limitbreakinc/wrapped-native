pragma solidity 0.8.25;

/*
import "ds-test/test.sol";

import "./weth.sol";
import "./weth9.sol";
*/

import "forge-std/Test.sol";
import "../WETH9.sol";

interface ERC20Events {
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
}

interface ERC20 is ERC20Events {
    function totalSupply() external view returns (uint);
    function balanceOf(address guy) external view returns (uint);
    function allowance(address src, address guy) external view returns (uint);

    function approve(address guy, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(
        address src, address dst, uint wad
    ) external returns (bool);
}

contract WETHEvents is ERC20Events {
    event Join(address indexed dst, uint wad);
    event Exit(address indexed src, uint wad);
}

abstract contract WETH is ERC20, WETHEvents {
    function join() public payable virtual;
    function exit(uint wad) public virtual;
}

contract WETH9Behavior is WETH9 {
    function join() public payable {
        deposit();
    }
    function exit(uint wad) public {
        withdraw(wad);
    }
}

contract WETH9BehaviorTest is Test, WETHEvents {
    WETH9Behavior weth;
    Guy   a;
    Guy   b;
    Guy   c;

    function setUp() public {
        weth  = this.newWETH();
        a     = this.newGuy();
        b     = this.newGuy();
        c     = this.newGuy();
    }

    function newWETH() public returns (WETH9Behavior) {
        return new WETH9Behavior();
    }

    function newGuy() public returns (Guy) {
        return new Guy(weth);
    }

    function test_initial_state() public {
        assert_eth_balance   (a, 0 * 0.001 ether);
        assert_weth_balance  (a, 0 * 0.001 ether);
        assert_eth_balance   (b, 0 * 0.001 ether);
        assert_weth_balance  (b, 0 * 0.001 ether);
        assert_eth_balance   (c, 0 * 0.001 ether);
        assert_weth_balance  (c, 0 * 0.001 ether);

        assert_weth_supply   (0 * 0.001 ether);
    }

    function test_join() public {
        // expectEventsExact    (address(weth));

        perform_join         (a, 3 * 0.001 ether);
        assert_weth_balance  (a, 3 * 0.001 ether);
        assert_weth_balance  (b, 0 * 0.001 ether);
        assert_eth_balance   (a, 0 * 0.001 ether);
        assert_weth_supply   (3 * 0.001 ether);

        perform_join         (a, 4 * 0.001 ether);
        assert_weth_balance  (a, 7 * 0.001 ether);
        assert_weth_balance  (b, 0 * 0.001 ether);
        assert_eth_balance   (a, 0 * 0.001 ether);
        assert_weth_supply   (7 * 0.001 ether);

        perform_join         (b, 5 * 0.001 ether);
        assert_weth_balance  (b, 5 * 0.001 ether);
        assert_weth_balance  (a, 7 * 0.001 ether);
        assert_weth_supply   (12 * 0.001 ether);
    }

    function testFail_exital_1() public {
        perform_exit         (a, 1 wei);
    }

    function testFail_exit_2() public {
        perform_join         (a, 1 * 0.001 ether);
        perform_exit         (b, 1 wei);
    }

    function testFail_exit_3() public {
        perform_join         (a, 1 * 0.001 ether);
        perform_join         (b, 1 * 0.001 ether);
        perform_exit         (b, 1 * 0.001 ether);
        perform_exit         (b, 1 wei);
    }

    function test_exit() public {
        // expectEventsExact    (address(weth));

        perform_join         (a, 7 * 0.001 ether);
        assert_weth_balance  (a, 7 * 0.001 ether);
        assert_eth_balance   (a, 0 * 0.001 ether);

        perform_exit         (a, 3 * 0.001 ether);
        assert_weth_balance  (a, 4 * 0.001 ether);
        assert_eth_balance   (a, 3 * 0.001 ether);

        perform_exit         (a, 4 * 0.001 ether);
        assert_weth_balance  (a, 0 * 0.001 ether);
        assert_eth_balance   (a, 7 * 0.001 ether);
    }

    function testFail_transfer_1() public {
        perform_transfer     (a, 1 wei, b);
    }

    function testFail_transfer_2() public {
        perform_join         (a, 1 * 0.001 ether);
        perform_exit         (a, 1 * 0.001 ether);
        perform_transfer     (a, 1 wei, b);
    }

    function test_transfer() public {
        // expectEventsExact    (address(weth));

        perform_join         (a, 7 * 0.001 ether);
        perform_transfer     (a, 3 * 0.001 ether, b);
        assert_weth_balance  (a, 4 * 0.001 ether);
        assert_weth_balance  (b, 3 * 0.001 ether);
        assert_weth_supply   (7 * 0.001 ether);
    }

    function testFail_transferFrom_1() public {
        perform_transfer     (a,  1 wei, b, c);
    }

    function testFail_transferFrom_2() public {
        perform_join         (a, 7 * 0.001 ether);
        perform_approval     (a, 3 * 0.001 ether, b);
        perform_transfer     (b, 4 * 0.001 ether, a, c);
    }

    function test_transferFrom() public {
        // expectEventsExact    (address(this));

        perform_join         (a, 7 * 0.001 ether);
        perform_approval     (a, 5 * 0.001 ether, b);
        assert_weth_balance  (a, 7 * 0.001 ether);
        assert_allowance     (b, 5 * 0.001 ether, a);
        assert_weth_supply   (7 * 0.001 ether);

        perform_transfer     (b, 3 * 0.001 ether, a, c);
        assert_weth_balance  (a, 4 * 0.001 ether);
        assert_weth_balance  (b, 0 * 0.001 ether);
        assert_weth_balance  (c, 3 * 0.001 ether);
        assert_allowance     (b, 2 * 0.001 ether, a);
        assert_weth_supply   (7 * 0.001 ether);

        perform_transfer     (b, 2 * 0.001 ether, a, c);
        assert_weth_balance  (a, 2 * 0.001 ether);
        assert_weth_balance  (b, 0 * 0.001 ether);
        assert_weth_balance  (c, 5 * 0.001 ether);
        assert_allowance     (b, 0 * 0.001 ether, a);
        assert_weth_supply   (7 * 0.001 ether);
    }

    //------------------------------------------------------------------
    // Helper functions
    //------------------------------------------------------------------

    function assert_eth_balance(Guy guy, uint balance) public {
        assertEq(address(guy).balance, balance);
    }

    function assert_weth_balance(Guy guy, uint balance) public {
        assertEq(weth.balanceOf(address(guy)), balance);
    }

    function assert_weth_supply(uint supply) public {
        assertEq(weth.totalSupply(), supply);
    }

    function perform_join(Guy guy, uint wad) public {
        emit Join(address(guy), wad);
        guy.join{value: wad}();
    }

    function perform_exit(Guy guy, uint wad) public {
        emit Exit(address(guy), wad);
        guy.exit(wad);
    }

    function perform_transfer(
        Guy src, uint wad, Guy dst
    ) public {
        emit Transfer(address(src), address(dst), wad);
        src.transfer(dst, wad);
    }

    function perform_approval(
        Guy src, uint wad, Guy guy
    ) public {
        emit Approval(address(src), address(guy), wad);
        src.approve(guy, wad);
    }

    function assert_allowance(
        Guy guy, uint wad, Guy src
    ) public {
        assertEq(weth.allowance(address(src), address(guy)), wad);
    }

    function perform_transfer(
        Guy guy, uint wad, Guy src, Guy dst
    ) public {
        emit Transfer(address(src), address(dst), wad);
        guy.transfer(src, dst, wad);
    }
}

contract Guy {
    WETH9Behavior weth;

    constructor(WETH9Behavior _weth) public {
        weth = _weth;
    }

    function join() payable public {
        weth.join{value: msg.value}();
    }

    function exit(uint wad) public {
        weth.exit(wad);
    }

    fallback() external payable {}

    receive() external payable {}

    function transfer(Guy dst, uint wad) public {
        require(weth.transfer(address(dst), wad));
    }

    function approve(Guy guy, uint wad) public {
        require(weth.approve(address(guy), wad));
    }

    function transfer(Guy src, Guy dst, uint wad) public {
        require(weth.transferFrom(address(src), address(dst), wad));
    }
}