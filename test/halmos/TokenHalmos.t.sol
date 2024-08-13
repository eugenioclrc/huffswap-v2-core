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

    function check_mint(address user, uint256 amount) public {
        assert(token.totalSupply() == 0);

        token.mint(user, amount);

        assert(token.totalSupply() == amount);
        assert(token.balanceOf(user) == amount);
    }

    function check_mintAndBurn(address user, uint256 amountMint, uint256 amountBurn) public {
        assert(token.totalSupply() == 0);

        token.mint(user, amountMint);

        assert(token.totalSupply() == amountMint);

        if (amountBurn > amountMint) {
            (bool sucess, ) = address(token).call(abi.encodeWithSelector(IToken.burn.selector, user, amountBurn));
            assert(!sucess);
            assert(token.balanceOf(user) == amountMint);
            assert(token.totalSupply() == amountMint);
        } else {
            token.burn(user, amountBurn);

            assert(token.balanceOf(user) == amountMint - amountBurn);
            assert(token.totalSupply() == amountMint - amountBurn);
        }
    }

    function check_burnInsufficientBalance(address user, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount < type(uint256).max);
        vm.assume(burnAmount > mintAmount);

        token.mint(user, mintAmount);
        (bool sucess, ) = address(token).call(abi.encodeWithSelector(IToken.burn.selector, user, burnAmount));
        assert(!sucess);
    }

    function check_transferInsufficientBalance(address from, address to, uint256 mintAmount, uint256 sendAmount) public {
        vm.assume(mintAmount < type(uint256).max);
        vm.assume(sendAmount > mintAmount);

        token.mint(from, mintAmount);
        (bool sucess, ) = address(token).call(abi.encodeWithSelector(IToken.transfer.selector, to, sendAmount));
        assert(!sucess);
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

    function check_transferFromInsufficientAllowance(address owner, address spender, address to, uint256 approval, uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(approval < amount);

        token.mint(owner, amount);

        vm.prank(owner);
        assert(token.approve(spender, approval));
        assert(token.allowance(owner, spender) == approval);

        vm.prank(spender);
        (bool success, ) = address(token).call(abi.encodeWithSelector(IToken.transferFrom.selector, owner, to, amount));
        assert(!success);
    }

    function testTransferFromInsufficientAllowance(address to, uint256 approval, uint256 amount) public {
        approval = bound(approval, 0, amount - 1);

        address from = makeAddr("from");
        token.mint(from, amount);

        vm.prank(from);
        token.approve(address(this), approval);

        (bool success, ) = address(token).call(abi.encodeWithSelector(IToken.transferFrom.selector, from, to, amount));

        assert(!success);
    }



    function check_transferFrom(address from, address to, uint256 amount, uint256 approval, uint256 amountTransfer) public {
        vm.assume(approval < amount);
        vm.assume(amountTransfer <= approval);
        
        assert(token.balanceOf(from) == 0);
        assert(token.balanceOf(to) == 0);
        assert(token.totalSupply() == 0);

        token.mint(from, amount);

        vm.prank(from);
        assert(token.approve(address(this), approval));

        assert(token.allowance(from, address(this)) == approval);
        assert(token.transferFrom(from, to, amountTransfer));

        uint256 newAllowance = approval == type(uint256).max ? approval : approval - amountTransfer;

        assert(token.allowance(from, address(this)) == newAllowance);

        assert(token.totalSupply() == amount);

        if (from == to) {
            assert(token.balanceOf(from) == amount);
        } else {
            assert(token.balanceOf(from) == amount - amountTransfer);
            assert(token.balanceOf(to) == amountTransfer);
        }
    }
}
