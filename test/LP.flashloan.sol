// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";

import {compile} from "./Deploy.sol";

using {compile} for Vm;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {ILPToken} from "src/interfaces/ILPToken.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract FlashLoanReceiver {
    IERC20 token;
    address pair;
    bytes expectedData;
    address creator;

    constructor(address _pair, address _token, bytes memory _expectedData) {
        pair = _pair;
        token = IERC20(_token);
        expectedData = _expectedData;
        creator = msg.sender;
    }

    function uniswapV2Call(address sender, uint256 amount0Out, uint256 amount1Out, bytes memory data) external {
        require(msg.sender == pair, "FlashLoanReceiver: invalid sender");
        require(sender == creator, "FlashLoanReceiver: invalid sender");
        require(keccak256(data) == keccak256(expectedData), "FlashLoanReceiver: invalid data");
        token.transfer(pair, token.balanceOf(address(this)));
    }
}

contract FlahsloanTest is Test {
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

    function test_flashloan() external {
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

        FlashLoanReceiver receiverUni = new FlashLoanReceiver(address(uni), TOKEN0, "GM");
        IERC20(TOKEN0).transfer(address(receiverUni), 0.3041 ether);
        uni.swap(100 ether, 0, address(receiverUni), "GM");
        
        FlashLoanReceiver receiver = new FlashLoanReceiver(address(lptoken), TOKEN0, "GM");
        IERC20(TOKEN0).transfer(address(receiver), 0.3041 ether);
        lptoken.swap(100 ether, 0, address(receiver), "GM");

        //constructor(address _pair, address _token, bytes memory _expectedData) {

        /*
        assertEq(lptoken.balanceOf(userHuff), uni.balanceOf(userUni));
        assertEq(lptoken.price0CumulativeLast(), uni.price0CumulativeLast());
        assertEq(lptoken.price1CumulativeLast(), uni.price1CumulativeLast());

        MockERC20(TOKEN0).transfer(address(uni), 1 ether);
        MockERC20(TOKEN0).transfer(address(lptoken), 1 ether);

        assertEq(MockERC20(TOKEN0).balanceOf(address(uni)), amount0 + 1 ether);
        assertEq(MockERC20(TOKEN0).balanceOf(address(lptoken)), amount0 + 1 ether);

        assertEq(lptoken.kLast(), uni.kLast());
        /*
        address bob = makeAddr("bob");
        lptoken.swap(0, 0.9 ether, bob, hex"");

        address alice = makeAddr("alice");
        gas = gasleft();
        uni.swap(0, 0.9 ether, alice, hex"");
        gas = gas - gasleft();
        console.log("SWAP: Gas used uniswapV2: %d", gas);
        assertEq(lptoken.kLast(), uni.kLast());
        assertEq(lptoken.price0CumulativeLast(), uni.price0CumulativeLast());
        assertEq(lptoken.price1CumulativeLast(), uni.price1CumulativeLast());

        vm.startPrank(userHuff);
        assertTrue(lptoken.transfer(address(lptoken), 1000));
        vm.stopPrank();
        assertEq(lptoken.balanceOf(address(lptoken)), 1000);
        */
    }
}
