// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

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

    function testMintOverflow() public {
        token.mint(address(this), type(uint256).max / 3);
        token.mint(address(this), type(uint256).max / 3);
        token.mint(address(this), type(uint256).max / 3);

        vm.expectRevert(IToken.Overflow.selector);
        token.mint(address(this), type(uint256).max / 3);
    }

    function testMint(address from, uint256 amount) public {
        assertEq(token.totalSupply(), 0);

        vm.expectEmit(true, true, true, true);
        emit IToken.Transfer(address(0), from, amount);
        token.mint(from, amount);

        assertEq(token.balanceOf(from), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testMintAndBurn(address from, uint256 amountMint, uint256 amountBurn) public {
        assertEq(token.totalSupply(), 0);
        
        vm.expectEmit(true, true, true, true);
        emit IToken.Transfer(address(0), from, amountMint);
        token.mint(from, amountMint);
        
        assertEq(token.totalSupply(), amountMint);

        if (amountBurn > amountMint) {
            vm.expectRevert(IToken.InsufficientBalance.selector);
            token.burn(from, amountBurn);

            assertEq(token.balanceOf(from), amountMint);
            assertEq(token.totalSupply(), amountMint);
        } else {
            vm.expectEmit(true, true, true, true);
            emit IToken.Transfer(from, address(0), amountBurn);
            token.burn(from, amountBurn);
            
            assertEq(token.balanceOf(from), amountMint - amountBurn);
            assertEq(token.totalSupply(), amountMint - amountBurn);
        }
    }
    function testBurnInsufficientBalance(address to, uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 0, type(uint256).max - 1);
        burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

        token.mint(to, mintAmount);
        vm.expectRevert(IToken.InsufficientBalance.selector);
        token.burn(to, burnAmount);
    }

    function testTransferInsufficientBalance(address to, uint256 mintAmount, uint256 sendAmount) public {
        mintAmount = bound(mintAmount, 0, type(uint256).max - 1);
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        token.mint(address(this), mintAmount);
        vm.expectRevert(IToken.InsufficientBalance.selector);
        token.transfer(to, sendAmount);
    }

    function testTransfer(address to, uint256 amount) public {
        token.mint(address(this), amount);

        assertTrue(token.transfer(to, amount));

        if (address(this) == to) {
            assertEq(token.balanceOf(address(this)), amount);
        } else {
            assertEq(token.balanceOf(address(this)), 0);
            assertEq(token.balanceOf(to), amount);
        }
        assertEq(token.totalSupply(), amount);
    }

    function testTransferFromInsufficientAllowance(address to, uint256 approval, uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        approval = bound(approval, 0, amount - 1);
        
        address from = makeAddr("from");
        token.mint(from, amount);

        vm.prank(from);
        token.approve(address(this), approval);

        vm.expectRevert(IToken.InsufficientAllowance.selector);
        token.transferFrom(from, to, amount);
    }

    function testTransferFromInsufficientBalance(address to, uint256 mintAmount, uint256 sendAmount) public {
        mintAmount = bound(mintAmount, 0, type(uint256).max - 1);
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        address from = makeAddr("from");
        
        token.mint(from, mintAmount);

        vm.prank(from);
        token.approve(address(this), sendAmount);

        vm.expectRevert(IToken.InsufficientBalance.selector);
        token.transferFrom(from, to, sendAmount);
    }

    function testTransferFrom(address to, uint256 amount, uint256 approval, uint256 amountTransfer) public {
        approval = bound(approval, 0, amount);
        amountTransfer = bound(amountTransfer, 0, approval);

        address from = makeAddr("from");

        token.mint(from, amount);

        vm.prank(from);
        assertTrue(token.approve(address(this), approval));

        assertEq(token.allowance(from, address(this)), approval);
        assertTrue(token.transferFrom(from, to, amountTransfer));
        
        uint256 newAllowance = approval == type(uint256).max ? approval : approval - amountTransfer;
        console.log("infinity?", approval == type(uint256).max);
        console.log("newAllowance", newAllowance);

        assertEq(token.allowance(from, address(this)), newAllowance);
        
        assertEq(token.totalSupply(), amount);

        if (from == to) {
            assertEq(token.balanceOf(from), amount);
        } else {
            assertEq(token.balanceOf(from), amount - amountTransfer);
            assertEq(token.balanceOf(to), amountTransfer);
        }
    }
}
