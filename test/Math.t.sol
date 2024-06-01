// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {compile} from "./Deploy.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

using {compile} for Vm;

interface ISafeMathMock {
    error Overflow();
    error DivitionByZero();
    error MulDivFailed();

    function safeAdd(uint256, uint256) external view returns (uint256);
    function safeSub(uint256, uint256) external view returns (uint256);
    function safeMul(uint256, uint256) external view returns (uint256);
    function safeDiv(uint256, uint256) external view returns (uint256);
    function mulDiv(uint256, uint256, uint256) external view returns (uint256);
    function sqrt(uint256) external view returns (uint256);
}

contract MathTest is Test {
    ISafeMathMock math;

    function setUp() public {
        bytes memory bytecode = vm.compile("src/mocks/MathMock.huff");
        /// @solidity memory-safe-assembly
        ISafeMathMock _math;
        assembly {
            _math := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        math = _math;
    }

    function test_safeAddSimple() public {
        assertEq(math.safeAdd(0, 1), 1);
        assertEq(math.safeAdd(1, 0), 1);
        assertEq(math.safeAdd(1, 1), 2);
    }

    function test_safeAddRevert(uint256 x, uint256 y) public {
        x = bound(x, 1, type(uint256).max);
        y = bound(y, (type(uint256).max - x) + 1, type(uint256).max);
        vm.expectRevert(ISafeMathMock.Overflow.selector);
        math.safeAdd(x, y);

        vm.expectRevert(ISafeMathMock.Overflow.selector);
        math.safeAdd(y, x);
    }

    function test_safeAdd(uint256 x, uint256 y) public {
        unchecked {
            if (x + y < x) {
                vm.expectRevert(ISafeMathMock.Overflow.selector);
                math.safeAdd(x, y);
                return;
            }
        }
        assertEq(math.safeAdd(x, y), x + y);
    }

    function test_safeSubSimple() public {
        vm.expectRevert(ISafeMathMock.Overflow.selector);
        math.safeSub(0, 1);
        assertEq(math.safeSub(1, 0), 1);
        assertEq(math.safeSub(1, 1), 0);
    }

    function test_safeSub(uint256 x, uint256 y) public {
        if (x < y) {
            vm.expectRevert(ISafeMathMock.Overflow.selector);
            math.safeSub(x, y);
        } else {
            unchecked {
                uint256 res = x - y;
                assertEq(math.safeSub(x, y), res);
            }
        }
    }

    function test_mulBasic() public {
        assertEq(math.safeMul(0, 0), 0);
        assertEq(math.safeMul(0, 1), 0);
        assertEq(math.safeMul(1, 0), 0);
        assertEq(math.safeMul(1, 1), 1);
        assertEq(math.safeMul(10, 2), 10 + 10);
        assertEq(math.safeMul(2, 10), 10 + 10);
    }

    function test_mul(uint256 x, uint256 y) public {
        unchecked {
            if (x == 0 || y == 0) {
                assertEq(math.safeMul(x, y), 0);
                return;
            }

            uint256 res = x * y;
            if (res / x != y) {
                vm.expectRevert(ISafeMathMock.Overflow.selector);
                math.safeMul(x, y);
                return;
            }

            assertEq(math.safeMul(x, y), res);
        }
    }

    function test_div(uint256 x, uint256 y) public {
        if (y == 0) {
            vm.expectRevert(ISafeMathMock.DivitionByZero.selector);
            math.safeDiv(x, y);
        } else {
            unchecked {
                uint256 res = x / y;
                assertEq(math.safeDiv(x, y), res);
            }
        }
    }

    function testMulDiv() public {
        assertEq(math.mulDiv(2.5e27, 0.5e27, 1e27), 1.25e27);
        assertEq(math.mulDiv(2.5e18, 0.5e18, 1e18), 1.25e18);
        assertEq(math.mulDiv(2.5e8, 0.5e8, 1e8), 1.25e8);
        assertEq(math.mulDiv(369, 271, 1e2), 999);

        assertEq(math.mulDiv(1e27, 1e27, 2e27), 0.5e27);
        assertEq(math.mulDiv(1e18, 1e18, 2e18), 0.5e18);
        assertEq(math.mulDiv(1e8, 1e8, 2e8), 0.5e8);

        assertEq(math.mulDiv(2e27, 3e27, 2e27), 3e27);
        assertEq(math.mulDiv(3e18, 2e18, 3e18), 2e18);
        assertEq(math.mulDiv(2e8, 3e8, 2e8), 3e8);
    }

    function testMulDivEdgeCases() public {
        assertEq(math.mulDiv(0, 1e18, 1e18), 0);
        assertEq(math.mulDiv(1e18, 0, 1e18), 0);
        assertEq(math.mulDiv(0, 0, 1e18), 0);
    }

    function testMulDivZeroDenominatorReverts() public {
        vm.expectRevert(ISafeMathMock.MulDivFailed.selector);
        math.mulDiv(1e18, 1e18, 0);
    }

    function testMulDiv(uint256 x, uint256 y, uint256 denominator) public {
        unchecked {
            if (denominator == 0 || (x != 0 && (x * y) / x != y)) {
                vm.expectRevert(ISafeMathMock.MulDivFailed.selector);
                math.mulDiv(x, y, denominator);
                return;
            }
        }

        uint256 result = math.mulDiv(x, y, denominator);
        assertEq(result, (x * y) / denominator);

        uint256 expectedResult = FixedPointMathLib.mulDiv(x, y, denominator);
        assertEq(result, expectedResult);
    }

    function test_sqrt(uint256 n) public {
        assertEq(math.sqrt(n), FixedPointMathLib.sqrt(n));
    }
}
