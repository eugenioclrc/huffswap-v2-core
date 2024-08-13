// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "../Deploy.sol";

using {compile} for Vm;

interface IToken {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    error InsufficientBalance();
    error InsufficientAllowance();
    error Overflow();
}

contract TokenHalmosTest is Test, SymTest {
    IToken token;

    function setUp() public {
        bytes memory bytecode = vm.compile("src/mocks/PayableToken.huff");
        /// @solidity memory-safe-assembly
        IToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        token = _token;
    }

    function check_metadata() public {
        assert(keccak256(abi.encode(token.symbol())) == keccak256(abi.encode("HUFFSWAP-V2")));
        assert(keccak256(abi.encode(token.name())) == keccak256(abi.encode("HuffSwap PairV2")));
        assert(token.decimals() == 18);
    }

    function check_allowance(address owner, address spender, uint256 amount) public {
        assert(token.allowance(owner, spender) == 0);

        vm.prank(owner);
        assert(token.approve(spender, amount));

        assert(token.allowance(owner, spender) == amount);
    }

    function check_transfer(address from, address to, uint256 amount) public {
        assert(token.balanceOf(from) == 0);
        assert(token.balanceOf(to) == 0);

        vm.prank(from);
        token.mint(from, amount);
        assert(token.balanceOf(from) == amount);

        assert(token.transfer(to, amount));
        if (from != to) {
            assert(token.balanceOf(from) == 0);
            assert(token.balanceOf(to) == amount);
        } else {
            assert(token.balanceOf(from) == amount);
        }
    }

    function check_transferFrom(address owner, address spender, address to, uint256 amount) public {
        vm.assume(owner != address(0));
        vm.assume(spender != address(0));

        assert(token.balanceOf(owner) == 0);
        assert(token.balanceOf(to) == 0);

        assert(token.totalSupply() == 0);

        vm.prank(owner);
        token.mint(owner, amount);
        assert(token.balanceOf(owner) == amount);

        vm.prank(owner);
        assert(token.approve(spender, amount));
        assert(token.allowance(owner, spender) == amount);

        vm.prank(spender);
        assert(token.transferFrom(owner, to, amount));

        if (owner != to) {
            assert(token.balanceOf(owner) == 0);
            assert(token.balanceOf(to) == amount);
        } else {
            assert(token.balanceOf(owner) == amount);
        }

        assert(token.totalSupply() == amount);
        if (amount != type(uint256).max) {
            assert(token.allowance(owner, spender) == 0);
        }
    }
}
