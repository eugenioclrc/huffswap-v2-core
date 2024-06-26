// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";

import {compile} from "./Deploy.sol";

using {compile} for Vm;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {ILPToken} from "src/interfaces/ILPToken.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract LpTest is Test {
    error InsufficientBalance();
    error InsufficientAllowance();
    error Overflow();
    error SelectorNotFound();
    error Spender_onApprovalReceived_rejected();
    error Receiver_transferReceived_rejected();
    error WrongK();

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

    function test_metadata() public {
        assertEq(lptoken.name(), "HuffSwap PairV2");
        assertEq(lptoken.symbol(), "HUFFSWAP-V2");
        assertEq(lptoken.decimals(), 18);
        assertEq(lptoken.totalSupply(), 0);
        assertEq(lptoken.MINIMUM_LIQUIDITY(), 1000);
        lptoken.approve(address(0xbeef), 1000);
        assertEq(lptoken.allowance(address(this), address(0xbeef)), 1000);
        assertEq(lptoken.factory(), FACTORY);
        assertEq(lptoken.token0(), uni.token0());
        assertEq(lptoken.token1(), uni.token1());
    }

    function test_erc156() public {
        // ERC165:   0x01ffc9a7
        assertTrue(lptoken.supportsInterface(0x01ffc9a7));
        // ERC20:    0x36372b07
        assertTrue(lptoken.supportsInterface(0x36372b07));
        // ERC1363:  0xb0202a11
        assertTrue(lptoken.supportsInterface(0xb0202a11));
        // LP funcs: 0x7d4c6ff5
        assertTrue(lptoken.supportsInterface(0x7d4c6ff5));

        assertFalse(lptoken.supportsInterface(0x00000000));
        assertFalse(lptoken.supportsInterface(0x00000ff5));
        assertFalse(lptoken.supportsInterface(0x7d400000));
    }

    function test_erc156Fuzz(bytes4 s) public {
        // ERC165:   0x01ffc9a7
        // ERC20:    0x36372b07
        // ERC1363:  0xb0202a11
        // LP funcs: 0x7d4c6ff5
        if (s == 0x01ffc9a7 || s == 0x36372b07 || s == 0xb0202a11 || s == 0x7d4c6ff5) {
            assertTrue(lptoken.supportsInterface(s));
        } else {
            assertFalse(lptoken.supportsInterface(s));
        }
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
    }

    function test_swapBasicErrors() external {
        vm.expectRevert(ILPToken.InvalidTo.selector);
        lptoken.swap(0, 0.9 ether, TOKEN0, hex"");
        vm.expectRevert(ILPToken.InvalidTo.selector);
        lptoken.swap(0, 0.9 ether, TOKEN1, hex"");
        vm.expectRevert(ILPToken.InsufficientOutputAmount.selector);
        lptoken.swap(0, 0, address(0xbeef), hex"");

        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.swap(0, 1, address(0xbeef), hex"");
        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.swap(1, 0, address(0xbeef), hex"");
        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.swap(1, 1, address(0xbeef), hex"");

        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.mint(address(0));

        uint256 amount0 = 10 ether;
        uint256 amount1 = 20 ether;
        deal(TOKEN0, address(lptoken), amount0);
        deal(TOKEN1, address(lptoken), amount1);
        lptoken.mint(address(0));
        deal(TOKEN0, address(uni), amount0);
        deal(TOKEN1, address(uni), amount1);
        uni.mint(address(0));

        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.swap(0, 20 ether, address(0xbeef), hex"");
        vm.expectRevert("UniswapV2: INSUFFICIENT_LIQUIDITY");
        uni.swap(0, 20 ether, address(0xbeef), hex"");

        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.swap(10 ether, 0, address(0xbeef), hex"");
        vm.expectRevert("UniswapV2: INSUFFICIENT_LIQUIDITY");
        uni.swap(10 ether, 0, address(0xbeef), hex"");

        vm.expectRevert(ILPToken.InsufficientLiquidity.selector);
        lptoken.swap(10 ether, 20 ether, address(0xbeef), hex"");
        vm.expectRevert("UniswapV2: INSUFFICIENT_LIQUIDITY");
        uni.swap(10 ether, 20 ether, address(0xbeef), hex"");

        vm.expectRevert(ILPToken.InsufficientInputAmount.selector);
        lptoken.swap(0 ether, 1 ether, address(0xbeef), hex"");
        vm.expectRevert("UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
        uni.swap(0 ether, 1 ether, address(0xbeef), hex"");

        vm.expectRevert(ILPToken.InsufficientInputAmount.selector);
        lptoken.swap(1 ether, 0, address(0xbeef), hex"");
        vm.expectRevert("UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
        uni.swap(1 ether, 0, address(0xbeef), hex"");

        vm.expectRevert(ILPToken.InsufficientInputAmount.selector);
        lptoken.swap(1 ether, 1 ether, address(0xbeef), hex"");
        vm.expectRevert("UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
        uni.swap(1 ether, 1 ether, address(0xbeef), hex"");
    }

    function test_swapSimple() external {
        assertEq(lptoken.kLast(), uni.kLast());

        assertEq(lptoken.price0CumulativeLast(), uni.price0CumulativeLast());
        assertEq(lptoken.price1CumulativeLast(), uni.price1CumulativeLast());

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 1000 ether;
        deal(TOKEN0, address(lptoken), amount0);
        deal(TOKEN1, address(lptoken), amount1);
        deal(TOKEN0, address(uni), amount0);
        deal(TOKEN1, address(uni), amount1);
        deal(TOKEN0, address(this), 4 ether);
        deal(TOKEN1, address(this), 4 ether);

        address userUni = makeAddr("USER_UNI");
        address userHuff = makeAddr("USER_HUFF");
        assertEq(lptoken.balanceOf(userHuff), uni.balanceOf(userUni));

        uint256 gas;
        gas = gasleft();
        lptoken.mint(userHuff);
        gas = gas - gasleft();
        console.log("ADD LIQUIDTY: Gas used huffswapV2: %d", gas);

        gas = gasleft();
        uni.mint(userUni);
        gas = gas - gasleft();
        console.log("ADD LIQUIDTY: Gas used UniswapV2: %d", gas);

        assertEq(lptoken.balanceOf(userHuff), uni.balanceOf(userUni));
        assertEq(lptoken.price0CumulativeLast(), uni.price0CumulativeLast());
        assertEq(lptoken.price1CumulativeLast(), uni.price1CumulativeLast());

        MockERC20(TOKEN0).transfer(address(uni), 1 ether);
        MockERC20(TOKEN0).transfer(address(lptoken), 1 ether);

        assertEq(MockERC20(TOKEN0).balanceOf(address(uni)), amount0 + 1 ether);
        assertEq(MockERC20(TOKEN0).balanceOf(address(lptoken)), amount0 + 1 ether);

        assertEq(lptoken.kLast(), uni.kLast());

        address alice = makeAddr("alice");
        gas = gasleft();
        uni.swap(0, 0.9 ether, alice, hex"");
        gas = gas - gasleft();
        console.log("SWAP: Gas used uniswapV2: %d", gas);

        address bob = makeAddr("bob");
        gas = gasleft();
        lptoken.swap(0, 0.9 ether, bob, hex"");
        gas = gas - gasleft();
        console.log("SWAP: Gas used huffswapV2: %d", gas);

        assertEq(lptoken.kLast(), uni.kLast());
        assertEq(lptoken.price0CumulativeLast(), uni.price0CumulativeLast());
        assertEq(lptoken.price1CumulativeLast(), uni.price1CumulativeLast());

        vm.startPrank(userHuff);
        assertTrue(lptoken.transfer(address(lptoken), 1000));
        vm.stopPrank();
        assertEq(lptoken.balanceOf(address(lptoken)), 1000);
    }

    function test_sanitycheckBurn() public {
        assertEq(lptoken.kLast(), uni.kLast());

        assertEq(lptoken.price0CumulativeLast(), uni.price0CumulativeLast());
        assertEq(lptoken.price1CumulativeLast(), uni.price1CumulativeLast());

        uint256 amount0 = 1000 ether;
        uint256 amount1 = 1000 ether;
        deal(TOKEN0, address(lptoken), amount0);
        deal(TOKEN1, address(lptoken), amount1);
        deal(TOKEN0, address(uni), amount0);
        deal(TOKEN1, address(uni), amount1);
        deal(TOKEN0, address(this), 4 ether);
        deal(TOKEN1, address(this), 4 ether);

        address userUni = makeAddr("USER_UNI");
        address userHuff = makeAddr("USER_HUFF");

        lptoken.mint(userHuff);

        uni.mint(userUni);

        address bob = makeAddr("bob");
        address alice = makeAddr("alice");

        vm.startPrank(userHuff);
        assertTrue(lptoken.transfer(address(lptoken), 1 ether));
        vm.stopPrank();
        vm.startPrank(userUni);
        assertTrue(uni.transfer(address(uni), 1 ether));
        vm.stopPrank();

        lptoken.burn(bob);
        uni.burn(alice);

        assertEq(uni.balanceOf(address(uni)), lptoken.balanceOf(address(lptoken)));
        assertGt(IERC20(TOKEN0).balanceOf(bob), 0);
        assertEq(IERC20(TOKEN0).balanceOf(bob), IERC20(TOKEN0).balanceOf(alice));
        assertEq(IERC20(TOKEN1).balanceOf(bob), IERC20(TOKEN1).balanceOf(alice));

        vm.prank(userHuff);
        lptoken.approve(address(this), 1000);

        lptoken.transferFrom(userHuff, bob, 1000);
    }

    function test_sanityPayableToken() public {
        // 0x1296ee62: function transferAndCall(address,uint256) external returns (bool)
        vm.expectRevert(InsufficientBalance.selector);
        lptoken.transferAndCall(address(this), 1000);

        // 0x4000aea0: function transferAndCall(address,uint256,bytes) external returns (bool)
        vm.expectRevert(InsufficientBalance.selector);
        lptoken.transferAndCall(address(this), 1000, hex"ff");

        // 0xc1d34b89: function transferFromAndCall(address,address,uint256,bytes) external returns (bool)
        vm.expectRevert(InsufficientAllowance.selector);
        lptoken.transferFromAndCall(address(this), address(0xbeef), 100);

        // 0xd8fbe994: function transferFromAndCall(address,address,uint256) external returns (bool)
        vm.expectRevert(InsufficientAllowance.selector);
        lptoken.transferFromAndCall(address(this), address(0xbeef), 100, hex"ff");

        // 0x3177029f: function approveAndCall(address,uint256) external returns (bool)
        vm.expectRevert(Spender_onApprovalReceived_rejected.selector);
        lptoken.approveAndCall(address(this), 1000);

        // 0xcae9ca51: function approveAndCall(address,uint256,bytes) external returns (bool)
        vm.expectRevert(Spender_onApprovalReceived_rejected.selector);
        lptoken.approveAndCall(address(this), 1000, hex"fd");
    }
}
