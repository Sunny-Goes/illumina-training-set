// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.27;

import {Test} from "forge-std/Test.sol";

import {EcMulHarness} from "./EcMulControl.t.sol";
import {Fr} from "target/src/honk/Fr.sol";
import {Honk} from "target/src/honk/HonkTypes.sol";

/// @notice Win assertions for the missing-success-check bug in the target's
/// `ecMul` (target/src/honk/utils.sol).
contract PocTest is Test {
    /// @notice Calling the target's ecMul with the off-curve point (1,3) does
    /// NOT revert: the failed 0x07 staticcall leaves the pre-zeroed output
    /// buffer untouched, and the target copies it back as the "result". So the
    /// call succeeds and returns (0,0) — a value that is not the ecMul of the
    /// inputs (no such product exists for an off-curve point). A success-guarded
    /// ecMul would revert, making `ok == false` and failing this test.
    function test_ecMul_offCurvePoint_doesNotRevert_returnsStaleOutputBuffer() public {
        EcMulHarness harness = new EcMulHarness();

        Honk.G1Point memory offCurve = Honk.G1Point({x: 1, y: 3});
        Fr scalar = Fr.wrap(2);

        (bool ok, bytes memory ret) =
            address(harness).staticcall(abi.encodeCall(EcMulHarness.callEcMul, (scalar, offCurve)));
        assertTrue(ok, "target ecMul reverted on the off-curve point (1,3)");

        Honk.G1Point memory result = abi.decode(ret, (Honk.G1Point));
        assertEq(result.x, 0, "off-curve ecMul did not return the stale output buffer x");
        assertEq(result.y, 0, "off-curve ecMul did not return the stale output buffer y");
    }
}
