// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

using {compile} for Vm;

import {ILPToken} from "src/interfaces/ILPToken.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract LpMintTest is Test {
    address constant FACTORY = address(uint160(0xdead));
    address constant TOKEN0 = address(uint160(0x00beef));
    address constant TOKEN1 = address(uint160(0x00feeb));

    // constants
    uint256 constant MINIMUM_LIQUIDITY = 0x3e8; // min liquidity = 1000;

    // Storage slots
    bytes32 constant TOTAL_SUPPLY_SLOT = bytes32(uint256(0x010000000000000000000000000000000000000000));
    bytes32 constant KLAST_SLOT = bytes32(uint256(0x010000000000000000000000000000000000000001));
    bytes32 constant PACKED_RESERVE_SLOT = bytes32(uint256(0x010000000000000000000000000000000000000002));
    bytes32 constant P0CUMULATIVE_SLOT = bytes32(uint256(0x010000000000000000000000000000000000000003));
    bytes32 constant P1CUMULATIVE_SLOT = bytes32(uint256(0x010000000000000000000000000000000000000004));
    bytes32 constant LOCKED_SLOT = bytes32(uint256(0x010000000000000000000000000000000000000005));

    ILPToken lptoken;
    ILPToken uni;

    function setUp() public {
        bytes memory bytecode = vm.compile("src/LPToken.huff");
        /// @solidity memory-safe-assembly
        ILPToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        lptoken = _token;

        
        address factoryUni = makeAddr("FACTORY_UNI");
        vm.mockCall(factoryUni, abi.encodeWithSignature("feeTo()"), abi.encode(factoryUni));
        vm.startPrank(address(factoryUni));
        address uniswapV2Pair = address(deployCode("test/UniswapV2Pair.json"));
        (bool s, ) = uniswapV2Pair.call(abi.encodeWithSignature("initialize(address,address)", TOKEN0, TOKEN1));
        require(s, "UniswapV2Pair: failed to initialize");
        vm.stopPrank();
        
        uni = ILPToken(uniswapV2Pair);

        vm.label(uniswapV2Pair, "UniswapV2Pair");
        vm.label(address(_token), "HuffSwapV2Pair");

        
    }

    function setBalance(address token, uint256 amount) internal {
        vm.mockCall(token, abi.encodeWithSignature("balanceOf(address)", address(lptoken)), abi.encode(amount));
    }

    function setBalanceUni(address token, uint256 amount) internal {
        vm.mockCall(token, abi.encodeWithSignature("balanceOf(address)", address(uni)), abi.encode(amount));
    }

    function test_simpleMintInsufficientLiquidity(uint256 a, uint256 b) public {
        a = bound(a, 0, 1000000);
        b = bound(b, 0, 1000000);

        uint256 k = FixedPointMathLib.sqrt(a * b);
        while (k > 1000) {
            a = a / 2;
            b = b / 2;
            k = FixedPointMathLib.sqrt(a * b);
        }

        setBalance(TOKEN0, a);
        setBalance(TOKEN1, b);
        address user = makeAddr("user");

        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.mint(user);
    }

    function test_simpleMint() public {
        setBalance(TOKEN0, 100);
        setBalance(TOKEN1, 100);

        address user = makeAddr("user");

        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.mint(user);

        setBalance(TOKEN0, 1004);
        setBalance(TOKEN1, 1000);

        vm.expectEmit(true, true, true, true);
        emit ILPToken.Sync(1004, 1000);
        vm.expectEmit(true, true, true, true);
        emit ILPToken.Mint(address(this), 1004, 1000);

        vm.expectEmit(true, true, true, true);
        // liquidity burned to address 0 due first deposit
        emit IERC20.Transfer(address(0), address(0), 1000);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, 1);

        lptoken.mint(user);

        assertEq(lptoken.balanceOf(user), 1);
        assertEq(lptoken.balanceOf(address(0)), 1000);
        assertEq(lptoken.totalSupply(), 1001);
    }

    function testMintFuzzDiferential(uint256 amount0, uint256 amount1, uint256 amount3, uint256 amount4) public {
        amount3 = bound(amount3, 0, type(uint256).max - amount0);
        amount4 = bound(amount4, 0, type(uint256).max - amount1);
        setBalanceUni(TOKEN0, amount0);
        setBalanceUni(TOKEN1, amount1);
        setBalance(TOKEN0, amount0);
        setBalance(TOKEN1, amount1);

        address bob = makeAddr("bob");
        address alice = makeAddr("alice");

        (bool success, bytes memory ret) = address(uni).call(
            abi.encodeWithSignature("mint(address)", bob)
        );
        if(!success) {
            vm.expectRevert();
            lptoken.mint(alice);
            vm.expectRevert();
            uni.mint(bob);
        } else {
            uint256 minted = lptoken.mint(alice);
            assertEq(lptoken.balanceOf(alice), uni.balanceOf(bob));
            assertEq(lptoken.totalSupply(), uni.totalSupply());
            assertEq(minted, uni.balanceOf(bob));
        }

        // second mint!
        setBalanceUni(TOKEN0, amount0 + amount3);
        setBalanceUni(TOKEN1, amount1 + amount4);
        setBalance(TOKEN0, amount0 + amount3);
        setBalance(TOKEN1, amount1 + amount4);

        (success, ret) = address(uni).call(
            abi.encodeWithSignature("mint(address)", bob)
        );
        if(!success) {
            vm.expectRevert();
            lptoken.mint(alice);
            vm.expectRevert();
            uni.mint(bob);
        } else {
            lptoken.mint(alice);
            assertEq(lptoken.balanceOf(alice), uni.balanceOf(bob));
            assertEq(lptoken.totalSupply(), uni.totalSupply());
        }

        
    }
}
