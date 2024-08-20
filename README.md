# Wrapped Native

**The Wrapped Native contract wraps native tokens (e.g. Ether) into an ERC-20 token.  Wrapped Native is designed to be a more gas efficient, modern, more fully featured canonical replacement for WETH9 that can be deployed to a consistent, deterministic address on all chains.**

Wrapped Native features the following improvements over WETH9.

 - **Deterministically Deployable By Anyone To A Consistent Address On Any Chain!**
 - **More Gas Efficient Operations Than WETH9!**
 - **`approve` and `transfer` functions are payable** - will auto-deposit when `msg.value > 0`.  This feature will allow a user to wrap and approve a protocol in a single action instead of two, improving UX and saving gas.
 - **`depositTo`** - allows a depositor to specify the address to give WNATIVE to.  
   Much more gas efficient for operations such as native refunds from protocols compared to `deposit + transfer`.
 - **`withdrawToAccount`** - allows a withdrawer to withdraw to a different address.
 - **`withdrawSplit`** - allows a withdrawer to withdraw and send native tokens to several addresses at once.
 - **Permit Functions** - allows for transfers and withdrawals to be approved to spenders/operators gaslessly using EIP-712 signatures. Permitted withdrawals allow gas sponsorship to unwrap wrapped native tokens on the user's behalf, for a small convenience fee specified by the app. This is useful when user has no native tokens on a new chain but they have received wrapped native tokens.
 - **Lost Token Recovery** - allows anyone to recover ERC20/721/1155 tokens that were accidentally sent to this contract.
 - **Lost Wrapped Native Recovery** - allows anyone to recover wrapped native tokens that were accidentally sent to the zero address that would be otherwise lost.

## Usage

### Build

```shell
$ forge build
```

### Documentation
```shell
$ forge doc -s
```

### Test

```shell
$ forge test
```

### Deploy

Copy `.env.secrets.example` to `.env.secrets`.

Update the following environment variables in `.env.secrets` for your deployer address and the RPC/Etherscan API keys for the blockchain you are targeting:

```env
DEPLOYER_ADDRESS=
DEPLOYER_KEY=
RPC_URL=
ETHERSCAN_API_KEY=
```

Next, run:

```shell
$ chmod +x ./script/1-deploy.sh
$ ./script/1-deploy.sh
```

## Benchmarking WETH9 vs Wrapped Native

| Benchmark                         | WETH9  | Wrapped Native | Savings |
|-----------------------------------|--------|----------------|---------|
| deposit                           | 23974  | 23866          | 108     |
| withdraw                          | 13940  | 13545          | 395     |
| totalSupply                       | 343    | 550            | -207    |
| approve                           | 24420  | 24207          | 213     |
| transfer                          | 29962  | 29335          | 627     |
| transferFrom (Self)               | 29832  | 29351          | 481     |
| transferFrom (Operator Allowance) | 35648  | 34560          | 1088    |
| transferFrom (Operator Unlimited) | 32125  | 31609          | 516     |