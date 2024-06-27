// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";

import {compile} from "./Deploy.sol";

using {compile} for Vm;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {ILPToken} from "src/interfaces/ILPToken.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract SwapTest is Test {
    address constant FACTORY = 0xc00FFEC00ffEc00FfEC00fFeC00fFEc00ffeC00f;
    address constant TOKEN0 = 0xBEeFbeefbEefbeEFbeEfbEEfBEeFbeEfBeEfBeef;
    address constant TOKEN1 = 0xC0Dec0dec0DeC0Dec0dEc0DEC0DEC0DEC0DEC0dE;

    // constants
    uint256 constant MINIMUM_LIQUIDITY = 0x3e8; // min liquidity = 1000;

    ILPToken lptoken;
    ILPToken uni;

    address userUni = makeAddr("USER_UNI");
    address userHuff = makeAddr("USER_HUFF");
    // add this account to hold tokens and do some swaps
    address holder = makeAddr("HOLDER");

    error WrongK();
    error HookCallFail();

    function setUp() public {
        bytes memory bytecode = vm.compile("src/LPToken.huff");
        bytecode = abi.encodePacked(bytecode, abi.encode(FACTORY, TOKEN0, TOKEN1));
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
        vm.record();
        (bool s,) = uniswapV2Pair.call(abi.encodeWithSignature("initialize(address,address)", TOKEN0, TOKEN1));
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(uniswapV2Pair);
        require(s, "UniswapV2Pair: failed to initialize");
        vm.stopPrank();

        uni = ILPToken(uniswapV2Pair);

        vm.label(uniswapV2Pair, "UniswapV2Pair");
        vm.label(address(_token), "HuffSwapV2Pair");

        address _mock = address(new MockERC20());
        vm.etch(TOKEN0, _mock.code);
        vm.etch(TOKEN1, _mock.code);
        MockERC20(TOKEN0).initialize("Token 0", "tkn0", 18);
        MockERC20(TOKEN1).initialize("Token 1", "tkn1", 18);
        vm.label(TOKEN0, "Token0");
        vm.label(TOKEN1, "Token1");

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 1000 ether;
        deal(TOKEN0, address(lptoken), amount0);
        deal(TOKEN1, address(lptoken), amount1);
        deal(TOKEN0, address(uni), amount0);
        deal(TOKEN1, address(uni), amount1);
        deal(TOKEN0, holder, 4 ether);
        deal(TOKEN1, holder, 4 ether);

        lptoken.mint(userHuff);
        uni.mint(userUni);
    }

    address expectedSender;
    uint256 expectedAmount0;
    uint256 expectedAmount1;
    bytes expectedData;
    address expectedPair;
    IERC20 expectedToken;
    bytes32 expectedReserves;
    bytes32 expectedSlot;

    // useful for doing checks
    function uniswapV2Call(address sender, uint256 amount0Out, uint256 amount1Out, bytes memory data) external {
        assertEq(sender, expectedSender);
        assertEq(amount0Out, expectedAmount0);
        assertEq(amount1Out, expectedAmount1);
        assertEq(keccak256(data), keccak256(expectedData));
        assertEq(expectedPair, msg.sender);
        assertEq(expectedReserves, vm.load(expectedPair, expectedSlot));

        expectedToken.transfer(expectedPair, expectedToken.balanceOf(address(this)));
    }

    function test_swapSimpleCallback() external {
        assertEq(uni.token0(), TOKEN0);
        address sender = makeAddr("SENDER");
        expectedSender = sender;

        expectedToken = IERC20(TOKEN0);
        expectedAmount0 = 1 ether;
        expectedAmount1 = 0;
        expectedData = "GM";
        expectedPair = address(uni);
        expectedReserves = 0x0000000100000000003635c9adc5dea0000000000000003635c9adc5dea00000;
        // reserves slot in uniswap
        expectedSlot = bytes32(uint256(8));

        vm.expectRevert("UniswapV2: K");
        vm.prank(sender);
        uni.swap(1 ether, 0, address(this), "GM");

        expectedPair = address(lptoken);
        // reserves slot in huffswap
        expectedSlot = bytes32(uint256(0x010000000000000000000000000000000000000002));

        vm.expectRevert(WrongK.selector);
        vm.prank(sender);
        lptoken.swap(1 ether, 0, address(this), "GM");
    }

    function test_swapWrongK() external {
        vm.startPrank(holder);
        MockERC20(TOKEN0).transfer(address(uni), 1 ether);
        MockERC20(TOKEN0).transfer(address(lptoken), 1 ether);
        vm.stopPrank();

        vm.expectRevert("UniswapV2: K");
        address alice = makeAddr("alice");
        uni.swap(0, 0.9975 ether, alice, hex"");

        vm.expectRevert(WrongK.selector);
        address bob = makeAddr("bob");
        lptoken.swap(0, 0.9975 ether, bob, hex"");
    }

    function test_swapFuzz(uint256 amount, uint256 amountOut) external {
        amount = bound(amount, 0, 2 ether);
        amount = bound(amount, 0, 4 ether);
        vm.startPrank(holder);
        MockERC20(TOKEN0).transfer(address(uni), amount);
        MockERC20(TOKEN0).transfer(address(lptoken), amount);
        vm.stopPrank();

        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        try uni.swap(0, amountOut, alice, hex"") {
            lptoken.swap(0, amountOut, bob, hex"");
            assertEq(MockERC20(TOKEN0).balanceOf(alice), MockERC20(TOKEN0).balanceOf(bob));
            assertEq(MockERC20(TOKEN1).balanceOf(alice), MockERC20(TOKEN1).balanceOf(bob));

            assertEq(lptoken.kLast(), uni.kLast());
            assertEq(lptoken.price0CumulativeLast(), uni.price0CumulativeLast());
            assertEq(lptoken.price1CumulativeLast(), uni.price1CumulativeLast());
        } catch (bytes memory err) {
            vm.expectRevert();
            lptoken.swap(0, amountOut, bob, hex"");
        }
    }
}
