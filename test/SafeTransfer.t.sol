// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

//import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

using {compile} for Vm;

interface ITransferMock {
    error TransferFailed();

    function safeTransfer(address, address, uint256) external;
}

contract MathTest is Test {
    ITransferMock transferHelper;

    MockERC20 mock = new MockERC20();

    function setUp() public {
        bytes memory bytecode = vm.compile("src/mocks/TransferMock.huff");
        /// @solidity memory-safe-assembly
        ITransferMock _transferHelper;
        assembly {
            _transferHelper := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        transferHelper = _transferHelper;

        mock.initialize("Token 0", "tkn0", 18);
        
        deal(address(mock), address(transferHelper), 10 ether);
    }

    function test_transferSimple() public {
        assertEq(mock.balanceOf(address(transferHelper)), 10 ether);
        
        transferHelper.safeTransfer(address(mock), address(this), 1 ether);
        assertEq(mock.balanceOf(address(transferHelper)), 9 ether);
        
    }

}
