<center>
  <img src="logo.png" width="250px" />
</center>

# HuffSwap 
A simple DEX with BALLs 


## HuffSwap V2 Core

HuffSwap V2 Core is a decentralized trading protocol, offering a platform for trading ERC20 tokens in a permissionless and trustless manner through the use of smart contracts. It extends Foundry's capabilities by providing developers with a suite of tools for deploying and interacting with smart contracts on Ethereum, specifically tailored for creating and managing decentralized exchanges.

### Prerequisites

This steps are optionals if you want to change the Pair code and recompile everything.

1. Install [BALLs](https://github.com/Philogy/balls/tree/main)
2. Install [huff](https://github.com/huff-language/huff-rs?tab=readme-ov-file#installation)

### Recompile

```bash
sh build-erc20.sh
sh build-erc1363.sh
sh build-libs.sh
sh build-lp.sh
sh create-bytecode-pair.sh
```

Paste your new bytecode into [`Factory:getCreationCode`](https://github.com/eugenioclrc/huffswap-v2-core/blob/7b7572305d2ccce80c0d431beeba8948d9491080/src/Factory.sol#L32)

### Setup Instructions

To get started with HuffSwap V2 Core, ensure you have Foundry installed. Follow these steps:

1. Clone the HuffSwap V2 Core repository: `git clone https://github.com/eugenioclrc/huffswap-v2-core.git`
2. Navigate to the project directory: `cd huffswap-v2-core`
3. Install dependencies: `forge update`
4. Build the project: `forge build`
5. Run tests to ensure everything is set up correctly: `forge test`
