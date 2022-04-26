# Project Instructions

This is the Uniswap V1 Exchange in Solidity. There is no Factory code at this time.

Compile contracts and test with Hardhat

```shell
npx hardhat compile
npx hardhat test
```

Can also test in Remix
1. Copy Token.sol and Exchange.sol
2. Deploy Token.sol first then Exchange.sol
3. Before adding liquidity to Exchange, you will have to approve the Exchange contract address on Token.sol
