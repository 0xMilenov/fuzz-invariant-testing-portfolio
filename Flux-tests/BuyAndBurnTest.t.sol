// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./BaseTest.t.sol";

import "@const/Constants.sol";

import "forge-std/console.sol";

contract BuyAndBurnTest is BaseTest {
    address mintTo = makeAddr("mintTo");
    address burner = makeAddr("burner");

    function testCanStartLiquidity() public withStartedLiquidity {}

    function test_cannotBurnBeforeStart() public withStartedLiquidity {
        vm.expectRevert(FluxBuyAndBurn.NotStartedYet.selector);
        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));
    }

    function test_IntervalsAccumulateOverThenNextOneIfNotClaimed() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        vm.warp(block.timestamp + (INTERVAL_TIME * 2) + 1 minutes);
        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (totalAllocatedTitanXToBurn / INTERVALS_PER_DAY) * 2;

        assert(actualBurnedForTheInterval == expectedForInterval);
    }

    function test_CannotBurnForTheSameInterval() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        vm.prank(burner, burner);
        vm.expectRevert(FluxBuyAndBurn.IntervalAlreadyBurned.selector);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));
    }

    function test_AcumulatesForNextIntervals() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp() + 1);

        deal(address(TITAN_X), user, 1400000000e18 * 2);

        vm.startPrank(user);
        TITAN_X.approve(address(buyAndBurn), 1400000000e18);
        buyAndBurn.distributeTitanXForBurning(1400000000e18);

        vm.warp(block.timestamp + 23 hours + 52 minutes);

        TITAN_X.approve(address(buyAndBurn), 1400000000e18);
        buyAndBurn.distributeTitanXForBurning(1400000000e18);

        vm.stopPrank();

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        assertApproxEqAbs(actualBurnedForTheInterval, totalAllocatedTitanXToBurn, 1e3);
    }

    function test_IfFirstIntervalIsClaimedLateWeWillAccountForCorrectAmmount() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp() + (INTERVAL_TIME * 2) + 1 minutes);

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (totalAllocatedTitanXToBurn / INTERVALS_PER_DAY) * 3;

        assert(buyAndBurn.lastIntervalNumber() == 3);
        assert(actualBurnedForTheInterval == expectedForInterval);
    }

    function testAmountYetToBeDistributedGetsAcounted() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.startPrank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (totalAllocatedTitanXToBurn / INTERVALS_PER_DAY);

        assert(buyAndBurn.lastIntervalNumber() == 1);
        assert(actualBurnedForTheInterval == expectedForInterval);

        deal(address(TITAN_X), burner, 10_000e18);
        TITAN_X.approve(address(buyAndBurn), 10_000e18);
        buyAndBurn.distributeTitanXForBurning(10_000e18);

        vm.warp(block.timestamp + 1 days + 23 hours + 52 minutes);

        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        (, uint128 actualBurnedForTheInterva1) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        assertEq(actualBurnedForTheInterva1, totalAllocatedTitanXToBurn - expectedForInterval + 10_000e18, "failed");
    }

    function test_AccumulatesIntervalsCorrectlyEvenOnDifferentDays() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp + 2 hours));

        vm.warp(block.timestamp + 16 minutes);

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp + 2 hours));

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner, burner);

        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));
    }

    function test_CannotBurnBeforeAddingLiquidity() public {
        vm.warp(block.timestamp + 2 days);

        vm.prank(burner, burner);
        vm.expectRevert();
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));
    }

    function test_IfThereIsNoDistributionTheCurrentDayOfTheBnBDoesNotHaveAnything() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        address user = makeAddr("USER");

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        uint256 totalTitanXDistributedDay1 = buyAndBurn.totalTitanXDistributed();

        uint256 toDistribute = 100_000_000e18;

        deal(address(TITAN_X), user, toDistribute);

        vm.startPrank(user);
        TITAN_X.approve(address(buyAndBurn), toDistribute);
        buyAndBurn.distributeTitanXForBurning(toDistribute);
        vm.stopPrank();

        vm.warp(block.timestamp + 23 hours + 59 minutes);

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        (uint256 amountAllocated,) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 perInterval = (totalTitanXDistributedDay1 / INTERVALS_PER_DAY);

        assertApproxEqAbs(amountAllocated, totalTitanXDistributedDay1 - perInterval, 100);

        vm.warp(block.timestamp + 36 hours);

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        (uint256 amountAllocated1,) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        assertApproxEqAbs(amountAllocated1, toDistribute, 100);

        deal(address(TITAN_X), user, toDistribute);

        vm.startPrank(user);
        TITAN_X.approve(address(buyAndBurn), toDistribute);
        buyAndBurn.distributeTitanXForBurning(toDistribute);
        vm.stopPrank();

        vm.warp(block.timestamp + 24 hours + 1 minutes);

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        (uint256 amountAllocated2,) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 perInterval3 = (toDistribute / INTERVALS_PER_DAY);

        assertApproxEqAbs(amountAllocated2, perInterval3 * 89, 100);

        vm.warp(block.timestamp + 11 hours + 52 minutes);

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        assert(buyAndBurn.lastIntervalNumber() == uint256(INTERVALS_PER_DAY) * 4);
        assertApproxEqAbs(amountAllocated2, perInterval3 * 89, 100);
    }

    function test_CanClaimEveryNextInterval() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        vm.warp(block.timestamp + INTERVAL_TIME + 1 minutes);
        vm.prank(burner, burner);
        buyAndBurn.swapTitanXForFluxAndBurn(uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (totalAllocatedTitanXToBurn / INTERVALS_PER_DAY);

        assert(buyAndBurn.lastIntervalNumber() == 2);
        assert(actualBurnedForTheInterval == expectedForInterval);
    }
}
