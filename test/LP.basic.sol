// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

using {compile} for Vm;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {ILPToken} from "src/interfaces/ILPToken.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract LpTest is Test {
    address constant FACTORY = address(uint160(0xdead));
    address constant TOKEN0 = address(uint160(0x00beef));
    address constant TOKEN1 = address(uint160(0x00feeb));

    // constants
    uint256 constant MINIMUM_LIQUIDITY = 0x3e8; // min liquidity = 1000;

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

    function test_metadata() public {
        assertEq(lptoken.name(), "HuffSwap PairV2");
        assertEq(lptoken.symbol(), "HUFFSWAP-V2");
        assertEq(lptoken.decimals(), 18);
        assertEq(lptoken.totalSupply(), 0);
        assertEq(lptoken.MINIMUM_LIQUIDITY(), 1000);
    }

    function test_skim(uint256 amount0, uint256 amount1) public {
        deal(TOKEN0, address(lptoken), amount0);
        deal(TOKEN1, address(lptoken), amount1);

        // sanity check
        assertEq(MockERC20(TOKEN0).balanceOf(address(lptoken)), amount0);
        assertEq(MockERC20(TOKEN1).balanceOf(address(lptoken)), amount1);

        address user = makeAddr("USER");
        lptoken.skim(user);

        assertEq(MockERC20(TOKEN0).balanceOf(user), amount0);
        assertEq(MockERC20(TOKEN1).balanceOf(user), amount1);
    }

    function test_sync(uint256 amount0, uint256 amount1) public {
        deal(TOKEN0, address(lptoken), amount0);
        deal(TOKEN1, address(lptoken), amount1);

        address user = makeAddr("USER");

        if (amount0 == 0 || amount1 == 0) {
            vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
            lptoken.sync();
            lptoken.skim(user);

            assertEq(MockERC20(TOKEN0).balanceOf(address(user)), amount0);
            assertEq(MockERC20(TOKEN1).balanceOf(address(user)), amount1);
        } else if (amount0 > uint256(type(uint112).max) || amount1 > uint256(type(uint112).max)) {
            // revert
            vm.expectRevert(IERC20.Overflow.selector);
            lptoken.sync();
            lptoken.skim(user);

            assertEq(MockERC20(TOKEN0).balanceOf(address(user)), amount0);
            assertEq(MockERC20(TOKEN1).balanceOf(address(user)), amount1);
        } else {
            lptoken.sync();
            (uint112 reserve0, uint112 reserve1,) = lptoken.getReserves();

            assertEq(MockERC20(TOKEN0).balanceOf(address(lptoken)), amount0);
            assertEq(MockERC20(TOKEN1).balanceOf(address(lptoken)), amount1);
            assertEq(reserve0, amount0);
            assertEq(reserve1, amount1);
        }

        /*
        assertEq(MockERC20(TOKEN0).balanceOf(user), amount0);
        assertEq(MockERC20(TOKEN1).balanceOf(user), amount1);        
        */
    }
}
