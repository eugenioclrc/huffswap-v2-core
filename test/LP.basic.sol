// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

using {compile} for Vm;

import {ILPToken} from "src/interfaces/ILPToken.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract LpTest is Test {
    address constant FACTORY = address(uint160(0xdead));
    address constant TOKEN0 = address(uint160(0x00beef));
    address constant TOKEN1 = address(uint160(0x00feeb));

    // constants
    uint256 constant MINIMUM_LIQUIDITY = 0x3e8; // min liquidity = 1000;

    
    ILPToken lptoken;

    function setUp() public {
        bytes memory bytecode = vm.compile("src/LPToken.huff");
        /// @solidity memory-safe-assembly
        ILPToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        lptoken = _token;
    }

    function test_metadata() public {
        assertEq(lptoken.name(), "HuffSwap PairV2");
        assertEq(lptoken.symbol(), "HUFFSWAP-V2");
        assertEq(lptoken.decimals(), 18);
        assertEq(lptoken.totalSupply(), 0);
        assertEq(lptoken.MINIMUM_LIQUIDITY(), 1000);
    }
}
