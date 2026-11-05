// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";

import {ecMul} from "target/src/honk/utils.sol";
import {Fr} from "target/src/honk/Fr.sol";
import {Honk} from "target/src/honk/HonkTypes.sol";

/// @notice Thin external wrapper that forwards to the target's internal free
/// function `ecMul`. The free function is `view`, so this is `view` too. This
/// lives on its own contract so the test frame and the target frame are
/// distinct, exactly as in production usage.
contract EcMulHarness {
    function callEcMul(Fr value, Honk.G1Point memory point) external view returns (Honk.G1Point memory) {
        return ecMul(value, point);
    }
}

/// @notice Control / sanity tests for the ecMul path. No win assertions here.
contract EcMulControlTest is Test {
    EcMulHarness internal harness;

    function setUp() public {
        harness = new EcMulHarness();
    }

    /// @notice The raw ecMul precompile (0x07) must reject the off-curve point
    /// (1,3): 3^2 = 9 != 1^3 + 3 = 4. On rejection it returns no output at all.
    function test_rawPrecompile_rejectsOffCurvePoint() public {
        (bool ok, bytes memory out) = address(0x07).staticcall(abi.encode(uint256(1), uint256(3), uint256(2)));
        assertFalse(ok, "0x07 accepted the off-curve point (1,3)");
        assertEq(out.length, 0, "0x07 wrote output despite failing");
    }

    /// @notice The harness must faithfully forward to the target's ecMul: for a
    /// valid on-curve point (1,2) it returns the same non-identity product as
    /// the raw 0x07 precompile.
    function test_targetEcMul_onCurvePoint_matchesPrecompile() public {
        Honk.G1Point memory got = harness.callEcMul(Fr.wrap(2), Honk.G1Point({x: 1, y: 2}));

        (bool ok, bytes memory out) = address(0x07).staticcall(abi.encode(uint256(1), uint256(2), uint256(2)));
        assertTrue(ok, "raw 0x07 rejected the on-curve point (1,2)");
        (uint256 refX, uint256 refY) = abi.decode(out, (uint256, uint256));

        assertFalse(got.x == 0 && got.y == 0, "target ecMul returned the identity for (1,2)*2");
        assertEq(got.x, refX, "target ecMul x differs from raw 0x07");
        assertEq(got.y, refY, "target ecMul y differs from raw 0x07");
    }
}
