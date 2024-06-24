// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";

import {compile} from "./Deploy.sol";

using {compile} for Vm;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {IERC20} from "src/interfaces/IERC20.sol";

interface IMockSwap {
    function swapChecks(uint256 amount0Out, uint256 amount1Out, address to) external;
}

contract SwapUnitTest is Test {
    address constant FACTORY = 0xc00FFEC00ffEc00FfEC00fFeC00fFEc00ffeC00f;
    address constant TOKEN0 = 0xBEeFbeefbEefbeEFbeEfbEEfBEeFbeEfBeEfBeef;
    address constant TOKEN1 = 0xC0Dec0dec0DeC0Dec0dEc0DEC0DEC0DEC0DEC0dE;

    // constants
    uint256 constant MINIMUM_LIQUIDITY = 0x3e8; // min liquidity = 1000;

    IMockSwap lptoken;

    address userHuff = makeAddr("USER_HUFF");
    // add this account to hold tokens and do some swaps
    address holder = makeAddr("HOLDER");

    error WrongK();

    function setUp() public {
        bytes memory bytecode = vm.compile("src/mocks/LPTokenSwap.huff");
        bytecode = abi.encodePacked(bytecode, abi.encode(FACTORY, TOKEN0, TOKEN1));
        /// @solidity memory-safe-assembly

        IMockSwap _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        lptoken = _token;

        vm.label(address(_token), "HuffSwapV2Pair");

        address _mock = address(new MockERC20());
        vm.etch(TOKEN0, _mock.code);
        vm.etch(TOKEN1, _mock.code);
        MockERC20(TOKEN0).initialize("Token 0", "tkn0", 18);
        MockERC20(TOKEN1).initialize("Token 1", "tkn1", 18);
        vm.label(TOKEN0, "Token0");
        vm.label(TOKEN1, "Token1");
    }

    error InsufficientOutputAmount();
    error InvalidTo();

    function testMockSwapFuzz(uint256 amount0Out, uint256 amount1Out, address to) public {
        if (amount0Out == 0 && amount1Out == 0) {
            // InsufficientOutputAmount() = 0x42301c23
            vm.expectRevert(InsufficientOutputAmount.selector);
            lptoken.swapChecks(amount0Out, amount1Out, to);
        } else if (to == TOKEN0 || to == TOKEN1) {
            // InvalidTo() = 0x290fa188
            vm.expectRevert(InvalidTo.selector);
            lptoken.swapChecks(amount0Out, amount1Out, to);
        } else {
            lptoken.swapChecks(amount0Out, amount1Out, to);
        }
    }

    function testMockSwap() public {
        // InsufficientOutputAmount() = 0x42301c23
        vm.expectRevert(InsufficientOutputAmount.selector);
        lptoken.swapChecks(0, 0, makeAddr("to"));

        // InvalidTo() = 0x290fa188
        vm.expectRevert(InvalidTo.selector);
        lptoken.swapChecks(0, 1, TOKEN0);
        vm.expectRevert(InvalidTo.selector);
        lptoken.swapChecks(0, 1, TOKEN1);
    }
}
