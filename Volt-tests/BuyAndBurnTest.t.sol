// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./BaseTest.t.sol";

import {console2} from "forge-std/console2.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/const/Constants.sol";

import {console2} from "forge-std/console2.sol";

contract BuyAndBurnTest is BaseTest {
    address mintTo = makeAddr("mintTo");
    address burner = makeAddr("burner");

    function test_DistributesCorrectAmountForTheDay() external withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        uint256 expectedTitanXForTheDay =
            (totalAllocatedTitanXToBurn * buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp))) / WAD;

        uint256 expectedTitanXForTheInterval = expectedTitanXForTheDay / INTERVALS_PER_DAY;

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        assert(expectedTitanXForTheInterval == actualBurnedForTheInterval);
    }

    function test_cannotBurnBeforeStart() public withStartedLiquidity {
        console2.log(block.timestamp);
        console2.log(buyAndBurn.startTimeStamp());
        vm.expectRevert(VoltBuyAndBurn.NotStartedYet.selector);
        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);
    }

    function test_IntervalsAccumulateOverThenNextOneIfNotClaimed() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        vm.warp(block.timestamp + INTERVAL_TIME * 2);
        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        uint256 actualTitanXForTheDay =
            (totalAllocatedTitanXToBurn * buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp))) / WAD;

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (actualTitanXForTheDay / INTERVALS_PER_DAY) * 2;

        assert(actualBurnedForTheInterval == expectedForInterval);
    }

    function test_CannotBurnForTheSameInterval() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        vm.prank(burner);
        vm.expectRevert(VoltBuyAndBurn.IntervalAlreadyBurned.selector);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);
    }

    function test_IfFirstIntervalIsClaimedLateWeWillAccountForCorrectAmmount() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp() + (INTERVAL_TIME * 2) + 1 minutes);

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        uint256 actualTitanXForTheDay =
            (totalAllocatedTitanXToBurn * buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp))) / WAD;

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (actualTitanXForTheDay / INTERVALS_PER_DAY) * 3;

        assert(buyAndBurn.lastIntervalNumber() == 3);
        assert(actualBurnedForTheInterval == expectedForInterval);
    }

    function test_AccumulatesIntervalsCorrectlyEvenOnDifferentDays() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        vm.warp(block.timestamp + INTERVAL_TIME + 1 minutes);

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);
    }

    function test_ThereIsCorrectDailyAllocation() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        uint256 allocation = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.42e18 == allocation);

        /* == 2 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay2 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.39e18 == currWeekDay2);

        /* == 3 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay3 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.36e18 == currWeekDay3);

        /* == 4 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay4 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.33e18 == currWeekDay4);

        /* == 5 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay5 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.3e18 == currWeekDay5);

        /* == 6 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay6 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.27e18 == currWeekDay6);

        /* == 7 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay7 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.24e18 == currWeekDay7);

        /* == 8 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay8 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.21e18 == currWeekDay8);

        /* == 9 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay9 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.18e18 == currWeekDay9);

        /* == 10 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay10 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.15e18 == currWeekDay10);

        /* == 11 ==  */

        vm.warp(block.timestamp + 1 days);

        uint256 currWeekDay11 = buyAndBurn.getDailyTitanXAllocation(uint32(block.timestamp));

        assert(0.15e18 == currWeekDay11);
    }

    function test_CannotBurnBeforeAddingLiquidity() public {
        vm.warp(block.timestamp + 2 days);

        vm.prank(burner);
        vm.expectRevert();
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);
    }

    function test_sends50PercentToTheVolt() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        assert(volt.balanceOf(address(theVolt)) == 0);
        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        assert(volt.balanceOf(address(theVolt)) != 0);
    }

    function test_DistributionGetsAccountedCorrectly() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        vm.warp(block.timestamp + INTERVAL_TIME + 1 minutes);
        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        uint256 actualTitanXForTheDay =
            (totalAllocatedTitanXToBurn * buyAndBurn.getDailyTitanXAllocation((uint32(block.timestamp)))) / WAD;

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (actualTitanXForTheDay / INTERVALS_PER_DAY);

        assert(buyAndBurn.lastIntervalNumber() == 2);
        assert(actualBurnedForTheInterval == expectedForInterval);
    }

    function test_CanClaimEveryNextInterval() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());

        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        vm.warp(block.timestamp + INTERVAL_TIME + 1 minutes);
        vm.prank(burner);
        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        uint256 totalAllocatedTitanXToBurn = buyAndBurn.totalTitanXDistributed();

        uint256 actualTitanXForTheDay =
            (totalAllocatedTitanXToBurn * buyAndBurn.getDailyTitanXAllocation((uint32(block.timestamp)))) / WAD;

        (, uint128 actualBurnedForTheInterval) = buyAndBurn.intervals(buyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (actualTitanXForTheDay / INTERVALS_PER_DAY);

        assert(buyAndBurn.lastIntervalNumber() == 2);
        assert(actualBurnedForTheInterval == expectedForInterval);
    }
}
