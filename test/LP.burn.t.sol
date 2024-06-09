// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

using {compile} for Vm;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {ILPToken} from "src/interfaces/ILPToken.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract LpTest is Test {
    address constant FACTORY = 0xc00FFEC00ffEc00FfEC00fFeC00fFEc00ffeC00f;
    address constant TOKEN0 = 0xBEeFbeefbEefbeEFbeEfbEEfBEeFbeEfBeEfBeef;
    address constant TOKEN1 = 0xC0Dec0dec0DeC0Dec0dEc0DEC0DEC0DEC0DEC0dE;

    // constants
    uint256 constant MINIMUM_LIQUIDITY = 0x3e8; // min liquidity = 1000;

    ILPToken lptoken;
    ILPToken uni;

    function setUp() public {
        bytes memory bytecode = vm.compile("src/LPToken.huff");
        bytecode = abi.encodePacked(bytecode, abi.encode(FACTORY, TOKEN0, TOKEN1));
        ILPToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        lptoken = _token;

        address factoryUni = makeAddr("FACTORY_UNI");
        vm.mockCall(factoryUni, abi.encodeWithSignature("feeTo()"), abi.encode(factoryUni));
        vm.startPrank(address(factoryUni));
        address uniswapV2Pair = address(deployCode("test/UniswapV2Pair.json"));
        (bool s,) = uniswapV2Pair.call(abi.encodeWithSignature("initialize(address,address)", TOKEN0, TOKEN1));
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
    }

    function test_burnSimple() external {
        uint256 amount0 = 1000 ether;
        uint256 amount1 = 1000 ether;
        deal(TOKEN0, address(lptoken), amount0);
        deal(TOKEN1, address(lptoken), amount1);
        deal(TOKEN0, address(uni), amount0);
        deal(TOKEN1, address(uni), amount1);

        address user = makeAddr("USER");
        address bob = makeAddr("BOB");
        address alice = makeAddr("ALICE");

        lptoken.mint(user);
        uni.mint(user);

        vm.prank(user);
        lptoken.transfer(address(lptoken), 1 ether);
        lptoken.burn(bob);

        vm.prank(user);
        uni.transfer(address(uni), 1 ether);
        uni.burn(alice);

        assertEq(uni.balanceOf(address(uni)), 0);
        assertEq(lptoken.balanceOf(address(lptoken)), 0);

        assertEq(IERC20(TOKEN0).balanceOf(bob), IERC20(TOKEN0).balanceOf(alice));
        assertEq(IERC20(TOKEN1).balanceOf(bob), IERC20(TOKEN1).balanceOf(alice));
    }
}
