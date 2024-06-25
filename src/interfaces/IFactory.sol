// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IOwnable} from "./IOwnable.sol";

/**
 * @author taken from https://github.com/LatamSwap/latamswap-dex
 */
interface IHuffSwapFactory is IOwnable {
    error ErrZeroAddress();
    error ErrIdenticalAddress();
    error ErrPairExists();
    error ErrNativoMustBeDeployed();

    function getPair(address fromToken, address toToken) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256 n) external view returns (address);

    /// @dev Event emitted when a new pair is created
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 allPairsLength);

    /**
     * @dev Creates a new pair with two tokens.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return pair The address of the newly created pair.
     * @notice Tokens must be different and not already have a pair.
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);

    function getOrCreatePair(address tokenA, address tokenB) external returns (address pair);

    /**
     * @dev Allows the owner to withdraw the entire balance of a specific token.
     * @param token The token to withdraw.
     * @param to The recipient address.
     */
    function withdraw(address token, address to) external;

    /**
     * @dev Allows the owner to withdraw a specified amount of a specific token.
     * @param token The token to withdraw.
     * @param to The recipient address.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(address token, address to, uint256 amount) external;
}
