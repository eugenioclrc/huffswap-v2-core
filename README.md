<img src="logo.png" />

# HuffSwap 
A simple DEX with BALLs 


## HuffSwap V2 Core

HuffSwap V2 Core is a decentralized trading protocol, offering a platform for trading ERC20 tokens in a permissionless and trustless manner through the use of smart contracts. It extends Foundry's capabilities by providing developers with a suite of tools for deploying and interacting with smart contracts on Ethereum, specifically tailored for creating and managing decentralized exchanges.

### Setup Instructions

To get started with HuffSwap V2 Core, ensure you have Foundry installed. Follow these steps:

1. Clone the HuffSwap V2 Core repository: `git clone https://github.com/eugenioclrc/huffswap-v2-core.git`
2. Navigate to the project directory: `cd huffswap-v2-core`
3. Install dependencies: `forge update`
4. Build the project: `forge build`
5. Run tests to ensure everything is set up correctly: `forge test`

### Common Tasks and Workflows

- **Deploying Contracts**: Use the `forge create` command with the specific contract you wish to deploy. For example, `forge create src/contracts/MyContract.sol:MyContract --rpc-url <your_rpc_url>`.
- **Interacting with Deployed Contracts**: Utilize `cast` to interact with contracts. For example, to call a function: `cast call <contract_address> "functionName(type)" --rpc-url <your_rpc_url>`.
- **Adding Liquidity**: To add liquidity to a pool, interact with the `addLiquidity` function of the Liquidity Pool contract.

For more detailed examples and workflows, refer to the [HuffSwap V2 Core documentation](https://github.com/eugenioclrc/huffswap-v2-core/docs).

