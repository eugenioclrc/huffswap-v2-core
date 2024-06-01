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

    function approveAndCall(address, uint256, bytes memory) external returns (bool);
    function approveAndCall(address, uint256) external returns (bool);

    function transferAndCall(address, uint256, bytes memory) external returns (bool);
    function transferAndCall(address, uint256) external returns (bool);

    error InsufficientBalance();
    error InsufficientAllowance();
    error Overflow();
    error Spender_onApprovalReceived_rejected();
    error Receiver_transferReceived_rejected();
}

contract PayableTokenTest is Test {
    bool shouldReceiveOk;

    address expectedApprovalOwner;
    address expectedOperator;
    address expectedFrom;
    uint256 expectedAmount = 1 ether;
    bytes expectedBytes;

    IToken token;

    function setUp() public {
        string[] memory cmd = new string[](2);
        cmd[0] = "sh";
        cmd[1] = "build-erc1363.sh";
        vm.ffi(cmd);

        bytes memory bytecode = vm.compile("src/mocks/PayableToken.huff");
        /// @solidity memory-safe-assembly
        IToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        token = _token;
    }

    function testApproveAndCallEmptyReverts() public {
        shouldReceiveOk = false;
        address EOA = makeAddr("EOA");

        EmptyContract empty = new EmptyContract();
        expectedApprovalOwner = EOA;
        expectedBytes = hex"";

        vm.startPrank(EOA);
        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(empty), 1 ether);

        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(this), 1 ether);

        // EOA call silent fails, but cant return acknoledge
        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(0xbeef), 1 ether);

        vm.stopPrank();
    }

    function testApproveAndCallEmpty() public {
        address EOA = makeAddr("EOA");
        expectedAmount = 0.5 ether;

        shouldReceiveOk = true;
        expectedApprovalOwner = EOA;
        vm.startPrank(EOA);
        assertTrue(token.approveAndCall(address(this), 0.5 ether));
        vm.stopPrank();

        assertEq(token.allowance(EOA, address(this)), 0.5 ether);

        token.mint(EOA, 1 ether);

        vm.expectRevert(IToken.InsufficientAllowance.selector);
        token.transferFrom(EOA, address(0xdead), 1 ether);
        assertEq(token.allowance(EOA, address(this)), 0.5 ether);

        vm.expectRevert(IToken.InsufficientBalance.selector);
        token.transferFrom(EOA, address(0xdead), 2 ether);

        assertTrue(token.transferFrom(EOA, address(0xdead), 0.5 ether));

        assertEq(token.allowance(EOA, address(this)), 0 ether);
        assertEq(token.balanceOf(EOA), 0.5 ether, "EOA should have 0.5 ether");
        assertEq(token.balanceOf(address(0xdead)), 0.5 ether, "dead address should have 0.5 ether");
        assertEq(token.totalSupply(), 1 ether, "total supply should be 1 ether");
    }

    function testApproveAndCallRevert(uint256 amount, bytes memory data) public {
        address EOA = makeAddr("EOA");

        expectedApprovalOwner = EOA;
        expectedBytes = data;
        expectedAmount = amount;

        EmptyContract empty = new EmptyContract();

        vm.startPrank(EOA);
        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(empty), amount);

        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(this), amount);

        // EOA call silent fails, but cant return acknoledge
        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(0xbeef), amount);

        vm.stopPrank();
    }

    function testApproveAndCallRevert(address spender, uint256 amount, bytes memory data) public {
        expectedApprovalOwner = address(this);
        expectedBytes = data;
        expectedAmount = amount;

        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(spender, amount, data);

        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(spender, amount);

        assertEq(token.allowance(address(this), spender), 0);
    }

    function testApproveAndCallEmptyRevert(uint256 amount) public {
        address EOA = makeAddr("EOA");

        expectedApprovalOwner = EOA;
        expectedAmount = amount;

        EmptyContract empty = new EmptyContract();

        vm.startPrank(EOA);
        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(empty), amount);

        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(this), amount);

        // EOA call silent fails, but cant return acknoledge
        vm.expectRevert(IToken.Spender_onApprovalReceived_rejected.selector);
        token.approveAndCall(address(0xbeef), amount);

        vm.stopPrank();
    }

    function testApproveAndCall(uint256 amount, bytes memory data) public {
        address EOA = makeAddr("EOA");
        expectedBytes = data;
        expectedAmount = amount;
        expectedApprovalOwner = EOA;

        uint256 minted = amount;
        if (amount > 0) {
            minted = bound(amount, 0, amount - 1);
            token.mint(EOA, minted);
        }

        shouldReceiveOk = true;
        vm.startPrank(EOA);
        token.approveAndCall(address(this), amount, data);
        vm.stopPrank();

        assertEq(token.allowance(EOA, address(this)), amount);

        if (amount != type(uint256).max && amount > 0) {
            vm.expectRevert( /*IToken.InsufficientBalance.selector*/ );
            token.transferFrom(EOA, address(0xdead), amount);
        }

        assertEq(token.allowance(EOA, address(this)), amount);

        token.mint(EOA, amount - minted);
        assertEq(token.balanceOf(EOA), amount);

        if (amount != type(uint256).max) {
            vm.expectRevert( /*IToken.InsufficientAllowance.selector*/ );
            token.transferFrom(EOA, address(0xdead), amount + 1);
        }

        assertTrue(token.transferFrom(EOA, address(0xdead), amount));
        assertEq(token.balanceOf(EOA), 0);
        assertEq(token.balanceOf(address(0xdead)), amount);

        if (amount != type(uint256).max) {
            assertEq(token.allowance(EOA, address(this)), 0 ether);
        } else {
            // infinity approve
            assertEq(token.allowance(EOA, address(this)), type(uint256).max);
        }
    }

    function testTransferAndCallRevertsEmpty() public {
        address EOA = makeAddr("EOA");
        EmptyContract empty = new EmptyContract();

        token.mint(EOA, 1 ether);

        vm.startPrank(EOA);

        vm.expectRevert(IToken.InsufficientBalance.selector);
        token.transferAndCall(address(this), 1 ether + 1);

        vm.expectRevert(IToken.Receiver_transferReceived_rejected.selector);
        token.transferAndCall(address(empty), 1 ether);

        vm.expectRevert(IToken.Receiver_transferReceived_rejected.selector);
        token.transferAndCall(address(this), 1 ether);

        // addr of precompiled contracts in https://book.getfoundry.sh/misc/precompile-registry
        address precompiledContract = address(0x02);
        vm.expectRevert(IToken.Receiver_transferReceived_rejected.selector);
        token.transferAndCall(address(0x02), 1 ether);

        vm.stopPrank();
    }

    function testTransferAndCallReverts(bytes memory data) public {
        address EOA = makeAddr("EOA");
        EmptyContract empty = new EmptyContract();

        token.mint(EOA, 1 ether);

        vm.startPrank(EOA);
        vm.expectRevert(IToken.InsufficientBalance.selector);
        token.transferAndCall(address(this), 1 ether + 1, data);

        vm.expectRevert(IToken.Receiver_transferReceived_rejected.selector);
        token.transferAndCall(address(empty), 1 ether, data);

        vm.expectRevert(IToken.Receiver_transferReceived_rejected.selector);
        token.transferAndCall(address(this), 1 ether, data);

        vm.expectRevert(IToken.InsufficientBalance.selector);
        token.transferAndCall(address(this), 1 ether + 1, data);

        // addr of precompiled contracts in https://book.getfoundry.sh/misc/precompile-registry
        address precompiledContract = address(0x02);
        vm.expectRevert(IToken.Receiver_transferReceived_rejected.selector);
        token.transferAndCall(address(0x02), 1 ether, data);

        vm.stopPrank();
    }

    function testTransferAndCallWork() public {
        address EOA = makeAddr("EOA");
        shouldReceiveOk = true;
        expectedOperator = EOA;
        expectedFrom = EOA;
        expectedBytes = "GM!";

        token.mint(EOA, 2 ether);

        vm.prank(EOA);
        token.transferAndCall(address(this), 1 ether, "GM!");

        expectedBytes = "This is a extra long byte data, longer than 32 bytes, te ensure that woks fine";
        vm.prank(EOA);
        token.transferAndCall(address(this), 1 ether, expectedBytes);

        vm.stopPrank();
    }

    function testTransferAndCallWorkEmpty() public {
        address EOA = makeAddr("EOA");
        expectedOperator = EOA;
        expectedFrom = EOA;
        expectedBytes = "";

        shouldReceiveOk = true;

        token.mint(EOA, 1 ether);

        vm.prank(EOA);
        token.transferAndCall(address(this), 1 ether);

        token.transfer(EOA, 1 ether);

        vm.prank(EOA);
        token.transferAndCall(address(this), 1 ether, "");
    }

    function onApprovalReceived(address owner, uint256 amount, bytes calldata b) external returns (bytes4) {
        assertEq(amount, expectedAmount, "wrong amount");
        assertEq(owner, expectedApprovalOwner, "wrong approval owner");
        assertEq(b, expectedBytes, "wrong byte data");
        if (shouldReceiveOk) {
            return this.onApprovalReceived.selector;
        }
    }

    function onTransferReceived(address operator, address from, uint256 amount, bytes memory b)
        external
        returns (bytes4)
    {
        if (shouldReceiveOk) {
            assertEq(amount, expectedAmount, "wrong amount");
            assertEq(operator, expectedOperator, "wrong operator and from");
            assertEq(from, expectedFrom, "wrong operator and from");
            assertEq(b, expectedBytes, "wrong byte data");

            return this.onTransferReceived.selector;
        }
    }
}

contract EmptyContract {}
