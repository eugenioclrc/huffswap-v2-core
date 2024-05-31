// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

using {compile} for Vm;


interface IToken {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract TokenTest is Test {

    IToken token;

    function setUp() public {
        bytes memory bytecode = vm.compile("src/mocks/TokenMock.huff");
        /// @solidity memory-safe-assembly
        IToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        token = _token;
    }

    function test_metadata() public {
        assertEq(token.symbol(), "HUFFSWAP-V2");
        assertEq(token.name(), "HuffSwap PairV2");
        assertEq(token.decimals(), 18);
    }

    function test_allowance(address owner, address spender, uint256 amount) public {
        assertEq(token.allowance(owner, spender), 0);
        vm.expectEmit(true, true, true, true);
        emit IToken.Approval(owner, spender, amount);        
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));

        assertEq(token.allowance(owner, spender), amount);
    }
}
