// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseTest} from "./BaseTest.sol";

import {console2} from "forge-std/console2.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/const/BuyAndBurnConst.sol";

import {InfernoMinting} from "../src/InfernoMinting.sol";
import {InfernoBuyAndBurn} from "../src/InfernoBuyAndBurn.sol";

import {console2} from "forge-std/console2.sol";

contract BuyAndBurnTest is BaseTest {
    address mintTo = makeAddr("mintTo");
    address burner = makeAddr("burner");

    function test_constructor() public {
        address titanX = makeAddr("TITANX");
        address blaze = makeAddr("BLAZE");
        address owner = makeAddr("owner");

        InfernoBuyAndBurn testInferno =
            new InfernoBuyAndBurn(uint32(block.timestamp), address(0x232131), titanX, blaze, owner);

        assert(testInferno.startTimeStamp() == uint32(block.timestamp));
        assert(address(testInferno.infernoToken()) == address(this));
        assert(testInferno.owner() == owner);
    }

    modifier withStartedLiquidity() {
        uint256 AMOUNT_TO_MINT = 60_000_000_000e18;

        deal(TITAN_X_ADDRESS, address(infernoMinting), AMOUNT_TO_MINT);

        vm.startPrank(address(infernoMinting));
        IERC20(TITAN_X_ADDRESS).approve(address(infernoBuyAndBurn), AMOUNT_TO_MINT);

        infernoBuyAndBurn.distributeTitanXForBurning(AMOUNT_TO_MINT);

        vm.stopPrank();

        vm.prank(infernoBuyAndBurn.owner());
        infernoBuyAndBurn.addLiquidityToInfernoBlazePool(uint32(block.timestamp), 0);
        _;
    }

    function testCanStartLiquidity() public withStartedLiquidity {}

    function test_DistributesCorrectAmountForTheDay() external withStartedLiquidity {
        vm.warp(infernoBuyAndBurn.startTimeStamp());

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = infernoBuyAndBurn.totalTitanXDistributed();

        ///@dev -> 400 since it is sunday
        uint256 expectedTitanXForTheDay =
            (totalAllocatedTitanXToBurn * getAllocation(infernoBuyAndBurn.currWeekDay())) / 10_000;
        ///@dev -> 51 Because every interval is 28 minutes
        uint256 expectedTitanXForTheInterval = expectedTitanXForTheDay / 48;

        uint256 actualTitanXForTheDay = (
            totalAllocatedTitanXToBurn * infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay())
        ) / BPS_DENOM;

        (, uint128 actualBurnedForTheInterval) = infernoBuyAndBurn.intervals(infernoBuyAndBurn.lastIntervalNumber());

        assert(expectedTitanXForTheDay == actualTitanXForTheDay);
        assert(expectedTitanXForTheInterval == actualBurnedForTheInterval);
    }

    function test_cannotBurnBeforeStart() public withStartedLiquidity {
        vm.prank(burner);
        vm.expectRevert(InfernoBuyAndBurn.NotStartedYet.selector);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));
    }

    function test_IntervalsAccumulateOverThenNextOneIfNotClaimed() public withStartedLiquidity {
        vm.warp(infernoBuyAndBurn.startTimeStamp());

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        vm.warp(block.timestamp + 60 minutes);
        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = infernoBuyAndBurn.totalTitanXDistributed();

        uint256 actualTitanXForTheDay = (
            totalAllocatedTitanXToBurn * infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay())
        ) / BPS_DENOM;

        (, uint128 actualBurnedForTheInterval) = infernoBuyAndBurn.intervals(infernoBuyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (actualTitanXForTheDay / 48) * 2;

        assert(actualBurnedForTheInterval == expectedForInterval);
    }

    function test_CannotBurnForTheSameInterval() public withStartedLiquidity {
        vm.warp(infernoBuyAndBurn.startTimeStamp());

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        vm.prank(burner);
        vm.expectRevert(InfernoBuyAndBurn.IntervalAlreadyBurned.selector);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));
    }

    function test_IfFirstIntervalIsClaimedLateWeWillAccountForCorrectAmmount() public withStartedLiquidity {
        vm.warp(infernoBuyAndBurn.startTimeStamp() + 60 minutes + 1);

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = infernoBuyAndBurn.totalTitanXDistributed();

        uint256 actualTitanXForTheDay = (
            totalAllocatedTitanXToBurn * infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay())
        ) / BPS_DENOM;

        (, uint128 actualBurnedForTheInterval) = infernoBuyAndBurn.intervals(infernoBuyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (actualTitanXForTheDay / 48) * 3;

        assert(infernoBuyAndBurn.lastIntervalNumber() == 3);
        assert(actualBurnedForTheInterval == expectedForInterval);
    }

    function getAllocation(uint8 _weekDay) internal pure returns (uint16 alloc) {
        if (_weekDay == 1) alloc = 400;
        else if (_weekDay == 2) alloc = 400;
        else if (_weekDay == 3) alloc = 1000;
        else if (_weekDay == 4) alloc = 1500;
        else if (_weekDay == 5) alloc = 1500;
        else if (_weekDay == 6) alloc = 400;
        else alloc = 400;
    }

    function test_AccumulatesIntervalsCorrectlyEvenOnDifferentDays() public withStartedLiquidity {
        vm.warp(infernoBuyAndBurn.startTimeStamp());

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        vm.warp(block.timestamp + 31 minutes);

        uint32 currAlocationBefore = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        uint256 beforeTitanXAllocation = (infernoBuyAndBurn.totalTitanXDistributed() * currAlocationBefore) / 10_000;

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        vm.warp(block.timestamp + 1 days);

        uint32 currAlocationAfter = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        uint256 afterTitanXAllocation = (infernoBuyAndBurn.totalTitanXDistributed() * currAlocationAfter) / 10_000;

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        (uint128 allocated,) = infernoBuyAndBurn.intervals(infernoBuyAndBurn.lastIntervalNumber());
    }

    function test_ThereIsCorrectDailyAllocation() public withStartedLiquidity {
        vm.warp(infernoBuyAndBurn.startTimeStamp());

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint8 currWeekDay1 = infernoBuyAndBurn.currWeekDay();
        uint16 expectedAllocation1 = getAllocation(currWeekDay1);

        uint256 actualDailyAllocation1 = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        assert(actualDailyAllocation1 == expectedAllocation1);

        /* == 2 ==  */

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint8 currWeekDay2 = infernoBuyAndBurn.currWeekDay();
        uint16 expectedAllocation2 = getAllocation(currWeekDay2);

        uint256 actualDailyAllocation2 = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        assert(expectedAllocation2 == actualDailyAllocation2);

        /* == 3 ==  */

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint8 currWeekDay3 = infernoBuyAndBurn.currWeekDay();
        uint16 expectedAllocation3 = getAllocation(currWeekDay3);

        uint256 actualDailyAllocation3 = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        assert(actualDailyAllocation3 == expectedAllocation3);

        /* == 4 ==  */

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint8 currWeekDay4 = infernoBuyAndBurn.currWeekDay();
        uint16 expectedAllocation4 = getAllocation(currWeekDay4);

        uint256 actualDailyAllocation4 = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        assert(actualDailyAllocation4 == expectedAllocation4);

        /* == 5 ==  */

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint8 currWeekDay5 = infernoBuyAndBurn.currWeekDay();
        uint16 expectedAllocation5 = getAllocation(currWeekDay5);

        uint256 actualDailyAllocation5 = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        assert(actualDailyAllocation5 == expectedAllocation5);

        /* == 6 ==  */

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint8 currWeekDay6 = infernoBuyAndBurn.currWeekDay();
        uint16 expectedAllocation6 = getAllocation(currWeekDay6);

        uint256 actualDailyAllocation6 = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        assert(actualDailyAllocation6 == expectedAllocation6);

        /* == 7 ==  */

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint8 currWeekDay7 = infernoBuyAndBurn.currWeekDay();
        uint16 expectedAllocation7 = getAllocation(currWeekDay7);

        uint256 actualDailyAllocation7 = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        assert(expectedAllocation7 == actualDailyAllocation7);

        /* == 8 ==  */

        vm.warp(block.timestamp + 1 days);

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));
        uint8 currWeekDay8 = infernoBuyAndBurn.currWeekDay();
        uint16 expectedAllocation8 = getAllocation(currWeekDay8);

        uint256 actualDailyAllocation8 = infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay());

        assert(actualDailyAllocation8 == expectedAllocation8);
    }

    function test_CannotAddLiquidityMoreThanOnce() public withStartedLiquidity {
        uint256 AMOUNT_TO_MINT = 60_000_000_000e18;

        deal(TITAN_X_ADDRESS, mintTo, AMOUNT_TO_MINT);

        vm.prank(infernoBuyAndBurn.owner());
        vm.expectRevert(InfernoBuyAndBurn.LiquidityAlreadyAdded.selector);
        infernoBuyAndBurn.addLiquidityToInfernoBlazePool(uint32(block.timestamp), 0);
    }

    function test_CannotAddLiquidityWithLessThan50BillionTitanX() public {
        uint256 AMOUNT_TO_MINT = 20_000_000_000e18;

        deal(TITAN_X_ADDRESS, address(infernoMinting), AMOUNT_TO_MINT);

        vm.startPrank(address(infernoMinting));
        IERC20(TITAN_X_ADDRESS).approve(address(infernoBuyAndBurn), AMOUNT_TO_MINT);

        infernoBuyAndBurn.distributeTitanXForBurning(AMOUNT_TO_MINT);

        vm.stopPrank();

        vm.prank(infernoBuyAndBurn.owner());
        vm.expectRevert(InfernoBuyAndBurn.NotEnoughTitanXForLiquidity.selector);
        infernoBuyAndBurn.addLiquidityToInfernoBlazePool(uint32(block.timestamp), 0);
    }

    function test_CannotBurnBeforeAddingLiquidity() public {
        vm.warp(block.timestamp + 2 days);

        vm.prank(burner);
        vm.expectRevert(InfernoBuyAndBurn.NotStartedYet.selector);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));
    }

    // function test_AfterLiquidityEverySellToUniswapBurns5Percent() public withStartedLiquidity {
    //     uint256 balanceOfPoolBefore = inferno.balanceOf(inferno.blazeInfernoPool());

    //     address trader = makeAddr("dasdsadsa");

    //     vm.prank(address(infernoMinting));
    //     inferno.mint(trader, 100e18);

    //     inferno.balanceOf(trader);

    //     vm.startPrank(trader);
    //     inferno.transfer(address(inferno.blazeInfernoPool()), 100e18);
    //     vm.stopPrank();

    //     uint256 balanceOfPoolAfter = inferno.balanceOf(inferno.blazeInfernoPool());

    //     assert(balanceOfPoolAfter - 100e18 != balanceOfPoolBefore);
    //     assert(balanceOfPoolBefore + 95e18 == balanceOfPoolAfter);
    // }

    function test_CanClaimEveryNextInterval() public withStartedLiquidity {
        vm.warp(infernoBuyAndBurn.startTimeStamp());

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        vm.warp(block.timestamp + 31 minutes);
        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint256 totalAllocatedTitanXToBurn = infernoBuyAndBurn.totalTitanXDistributed();

        uint256 actualTitanXForTheDay = (
            totalAllocatedTitanXToBurn * infernoBuyAndBurn.getDailyTitanXAllocation(infernoBuyAndBurn.currWeekDay())
        ) / BPS_DENOM;

        (, uint128 actualBurnedForTheInterval) = infernoBuyAndBurn.intervals(infernoBuyAndBurn.lastIntervalNumber());

        uint256 expectedForInterval = (actualTitanXForTheDay / 48);

        assert(infernoBuyAndBurn.lastIntervalNumber() == 2);
        assert(actualBurnedForTheInterval == expectedForInterval);
    }

    function test_TeamCanBurnFees() public withStartedLiquidity {
        vm.warp(infernoBuyAndBurn.startTimeStamp());

        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        vm.warp(block.timestamp + 30 minutes + 1);
        vm.prank(burner);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        uint256 balanceTitanXBefore = IERC20(TITAN_X_ADDRESS).balanceOf(address(infernoBuyAndBurn));
        uint256 balanceBlazeBefore = IERC20(BLAZE_ADDRESS).balanceOf(address(infernoBuyAndBurn));

        vm.prank(infernoBuyAndBurn.owner());
        infernoBuyAndBurn.burnFees();

        uint256 balanceTitanXAfter = IERC20(TITAN_X_ADDRESS).balanceOf(address(infernoBuyAndBurn));
        uint256 balanceBlazeAfter = IERC20(BLAZE_ADDRESS).balanceOf(address(infernoBuyAndBurn));

        assert(balanceTitanXBefore == balanceTitanXAfter);
        assert(balanceBlazeBefore == balanceBlazeAfter);
    }
}
