pragma solidity 0.8.26;

interface IWrappedNative {
    // ERC20 Specific
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    // ERC20 Metadata Specific
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    // Wrapped Native Specific
    event  Deposit(address indexed to, uint256 amount);
    event  Withdrawal(address indexed from, uint256 amount);

    function deposit() external payable;
    function withdraw(uint256 amount) external;
}