// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

using {compile} for Vm;

interface ILPToken {
    error Overflow();
    event Sync(uint112 reserve0, uint112 reserve1);

    function updateTest(uint256 balance0, uint256  balance1, uint112 reserve0, uint112 reserve1) external;
}

contract LpTest is Test {
    ILPToken lptoken;

    function setUp() public {
        bytes memory bytecode = vm.compile("src/mocks/LPToken.huff");
        /// @solidity memory-safe-assembly
        ILPToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        lptoken = _token;
    }

    function test_simpleUpdate() public {
        vm.expectRevert(ILPToken.Overflow.selector);
        lptoken.updateTest(uint256(type(uint112).max) + 1, 1, 1, 1);
        vm.expectRevert(ILPToken.Overflow.selector);
        lptoken.updateTest(1, uint256(type(uint112).max) + 1, 1, 1);

        vm.expectEmit(true, true, false, false);
        emit ILPToken.Sync(1, 1);
        lptoken.updateTest(1, 1, 1, 1);
        
    }
    
}
