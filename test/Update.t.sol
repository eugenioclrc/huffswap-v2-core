// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

using {compile} for Vm;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

interface ILPToken {
    error Overflow();

    event Sync(uint112 reserve0, uint112 reserve1);

    function updateTest(uint256 balance0, uint256 balance1, uint112 reserve0, uint112 reserve1) external;
}

contract MockUpdate is ILPToken {
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    using UQ112x112 for uint224;

    function updateState(bytes32 _state, uint256 _cumulative0, uint256 _cumulative1) public {
        assembly {
            sstore(0x00, _state)
        }
        price0CumulativeLast = _cumulative0;
        price1CumulativeLast = _cumulative1;
    }

    function updateTest(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) public {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) {
            revert Overflow();
        }

        uint112 _balance0 = uint112(balance0); // gas savings
        uint112 _balance1 = uint112(balance1); // gas savings

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp - blockTimestampLast); // overflow is desired
            if (timeElapsed != 0 && _reserve0 != 0 && _reserve1 != 0) {
                // * never overflows, and + overflow is desired
                price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        reserve0 = _balance0;
        reserve1 = _balance1;
        /// @dev max value for uint32 is 4294967295 = 7/feb/2106
        blockTimestampLast = uint32(block.timestamp);

        emit Sync(_balance0, _balance1);
    }
}

library UQ112x112 {
    uint224 constant Q112 = 2 ** 112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        assembly {
            z := mul(y, Q112)
        }
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        assembly {
            z := div(x, y)
        }
    }
}

contract UpdateTest is Test {
    ILPToken lptoken;
    MockUpdate mock = new MockUpdate();

    function setUp() public {
        bytes memory bytecode = vm.compile("src/mocks/LPTokenUpdate.huff");
        /// @solidity memory-safe-assembly
        ILPToken _token;
        assembly {
            _token := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        lptoken = _token;
    }

    function test_simpleUpdate() public {
        vm.expectRevert(ILPToken.Overflow.selector);
        lptoken.updateTest(uint256(type(uint112).max) + 1, 1, 1, 1);
        vm.expectRevert(ILPToken.Overflow.selector);
        lptoken.updateTest(1, uint256(type(uint112).max) + 1, 1, 1);

        vm.expectEmit(true, true, false, false);
        emit ILPToken.Sync(1, 1);
        lptoken.updateTest(1, 1, 1, 1);
    }

    bytes32 constant PACKED_RESERVE_SLOT = bytes32(uint256(0x0010000000000000000000000000000000000000002));
    bytes32 constant P0CUMULATIVE_SLOT = bytes32(uint256(0x0010000000000000000000000000000000000000003));
    bytes32 constant P1CUMULATIVE_SLOT = bytes32(uint256(0x0010000000000000000000000000000000000000004));

    function test_CumulativePrice(
        uint112 _reserve0,
        uint112 _reserve1,
        uint112 balance0,
        uint112 balance1,
        bytes32 initState,
        uint64 ts,
        uint256 _cumulative0,
        uint256 _cumulative1
    ) public {
        vm.store(address(lptoken), PACKED_RESERVE_SLOT, initState);
        vm.store(address(lptoken), P0CUMULATIVE_SLOT, bytes32(_cumulative0));
        vm.store(address(lptoken), P1CUMULATIVE_SLOT, bytes32(_cumulative1));
        vm.warp(ts);

        mock.updateState(initState, _cumulative0, _cumulative1);

        assertEq(vm.load(address(mock), bytes32(0x00)), vm.load(address(lptoken), PACKED_RESERVE_SLOT));
        assertEq(mock.price0CumulativeLast(), uint256(vm.load(address(lptoken), P0CUMULATIVE_SLOT)));
        assertEq(mock.price1CumulativeLast(), uint256(vm.load(address(lptoken), P1CUMULATIVE_SLOT)));

        mock.updateTest(balance0, balance1, _reserve0, _reserve1);
        vm.record();
        lptoken.updateTest(balance0, balance1, _reserve0, _reserve1);
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(lptoken));
        for (uint256 i = 0; i < reads.length; i++) {
            console.log("read: ", i);
            console.logBytes32(reads[i]);
        }
        for (uint256 i = 0; i < writes.length; i++) {
            console.log("write: ", i);
            console.logBytes32(writes[i]);
        }

        assertEq(vm.load(address(mock), bytes32(0x00)), vm.load(address(lptoken), PACKED_RESERVE_SLOT), "wrong reserve");
        assertEq(
            mock.price0CumulativeLast(),
            uint256(vm.load(address(lptoken), P0CUMULATIVE_SLOT)),
            "wrong price0CumulativeLast"
        );
        assertEq(
            mock.price1CumulativeLast(),
            uint256(vm.load(address(lptoken), P1CUMULATIVE_SLOT)),
            "wrong price1CumulativeLast"
        );

        /*
        uint256 price0CumulativeLast_start;
        uint256 price1CumulativeLast_start;
        uint256 price0CumulativeLast_end;
        uint256 price1CumulativeLast_end;
        
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            unchecked {
                // * never overflows, and + overflow is desired
                price0CumulativeLast_end = price0CumulativeLast_start + uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast_end = price1CumulativeLast_start + uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }

        
        bytes32 slot_p0cum = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd;
        bytes32 slot_p1cum = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc;
        vm.store(address(uni), slot_p0cum, bytes32(price0CumulativeLast_start));
        vm.store(address(uni), slot_p1cum, bytes32(price1CumulativeLast_start));

        uni.CumulativePrice(_reserve0, _reserve1, timeElapsed);

        assertEq(uint256(vm.load(address(uni), slot_p0cum)), price0CumulativeLast_end);
        assertEq(uint256(vm.load(address(uni), slot_p1cum)), price1CumulativeLast_end);
        */
    }
}
