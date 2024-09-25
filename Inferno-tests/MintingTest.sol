// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseTest} from "./BaseTest.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/const/BuyAndBurnConst.sol";

import {InfernoMinting} from "../src/InfernoMinting.sol";

import {console} from "forge-std/console.sol";

contract MintingTest is BaseTest {
    address buyer = makeAddr("buyer");

    function test_constructor() public {
        address buyAndBurn = makeAddr("buy andBurn");

        InfernoMinting testInferno = new InfernoMinting(buyAndBurn, address(0x321321), uint32(block.timestamp));

        assert(address(testInferno.titanX()) == address(0x321321));
        assert(testInferno.startTimestamp() == uint32(block.timestamp));
        assert(address(testInferno.buyAndBurn()) == buyAndBurn);
        assert(address(testInferno.inferno()) == address(this));
    }

    function test_CannotMintBeforeStart() public {
        vm.warp(infernoMinting.startTimestamp() - 100);
        vm.expectRevert(InfernoMinting.NotStartedYet.selector);
        infernoMinting.mint(100e18);
    }

    function test_CanClaimAfterStartTime() public {
        vm.warp(infernoMinting.startTimestamp());

        deal(TITAN_X_ADDRESS, buyer, 1e18);

        vm.startPrank(buyer);

        IERC20(TITAN_X_ADDRESS).approve(address(infernoMinting), 1e18);
        infernoMinting.mint(1e18);

        vm.stopPrank();

        (uint32 lastCycleId,,) = infernoMinting.getCurrentMintCycle();

        assert(lastCycleId == 1);
        assert(infernoMinting.amountToClaim(buyer, 1) == 1e18);
    }

    function test_newMintCycleStartsAfterGap() public {
        vm.warp(infernoMinting.startTimestamp());

        deal(TITAN_X_ADDRESS, buyer, 2e18);

        vm.startPrank(buyer);

        IERC20(TITAN_X_ADDRESS).approve(address(infernoMinting), 2e18);
        infernoMinting.mint(1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + infernoMinting.GAP_BETWEEN_CYCLE());

        vm.prank(buyer);
        infernoMinting.mint(1e18);

        (uint32 lastCycleId,,) = infernoMinting.getCurrentMintCycle();

        assert(95e16 == infernoMinting.getRatioForCycle(2));
        assert(lastCycleId == 2);
    }

    function test_WeDontUpdateMintCycleUntilItsOver() public {
        vm.warp(infernoMinting.startTimestamp());

        deal(TITAN_X_ADDRESS, buyer, 2e18);

        vm.startPrank(buyer);

        IERC20(TITAN_X_ADDRESS).approve(address(infernoMinting), 2e18);

        infernoMinting.mint(1e18);
        infernoMinting.mint(1e18);
        vm.stopPrank();

        (uint32 lastCycleId,,) = infernoMinting.getCurrentMintCycle();
        assert(1e18 == infernoMinting.getRatioForCycle(1));
        assert(lastCycleId == 1);
    }

    function test_displaysCorrectMintingCycle() public {
        uint32 duration = infernoMinting.MINT_CYCLE_DURATION();
        uint32 gap = infernoMinting.GAP_BETWEEN_CYCLE();
        uint32 startTime = infernoMinting.startTimestamp();

        vm.warp(startTime);

        (uint32 currentCycle, uint32 startsAt, uint32 endsAt) = infernoMinting.getCurrentMintCycle();

        assert(currentCycle == 1);
        assert(startsAt == startTime);
        assert(endsAt == startsAt + duration);

        vm.warp(startTime + gap);

        (uint32 currentCycleAfterGap, uint32 startsAtAfterGap, uint32 endsAtAfterGap) =
            infernoMinting.getCurrentMintCycle();

        assert(currentCycleAfterGap == 2);
        assert(startsAtAfterGap == startTime + gap);
        assert(endsAtAfterGap == startTime + gap + duration);
    }

    function test_UserCanBuyInferno() public {
        vm.warp(infernoMinting.startTimestamp());
        deal(TITAN_X_ADDRESS, buyer, 1e18);

        vm.startPrank(buyer);

        IERC20(TITAN_X_ADDRESS).approve(address(infernoMinting), 1e18);
        infernoMinting.mint(1e18);

        vm.stopPrank();

        assert(infernoMinting.amountToClaim(buyer, 1) == 1e18);
    }

    function test_UserCannotClaimBeforeMintPeriodEnd() public {
        deal(TITAN_X_ADDRESS, buyer, 1e18);

        vm.warp(infernoMinting.startTimestamp());

        vm.startPrank(buyer);

        IERC20(TITAN_X_ADDRESS).approve(address(infernoMinting), 1e18);
        infernoMinting.mint(1e18);

        vm.expectRevert(InfernoMinting.CycleStillOngoing.selector);
        infernoMinting.claim(1);
        vm.stopPrank();
    }

    function test_UserCanClaimAfterMintPeriodCycle() public {
        deal(TITAN_X_ADDRESS, buyer, 1e18);
        vm.warp(infernoMinting.startTimestamp());

        vm.startPrank(buyer);

        IERC20(TITAN_X_ADDRESS).approve(address(infernoMinting), 1e18);
        infernoMinting.mint(1e18);

        vm.warp(block.timestamp + 24 hours + 1);

        infernoMinting.claim(1);
        vm.stopPrank();

        uint256 userBalanceOfInferno = infernoMinting.inferno().balanceOf(buyer);

        assert(userBalanceOfInferno == 1e18);
    }

    function test_UserCannotBuyInAnEndedCycle() public {
        vm.warp(infernoMinting.startTimestamp() + infernoMinting.MINT_CYCLE_DURATION() + 1);

        deal(TITAN_X_ADDRESS, buyer, 1e18);

        vm.startPrank(buyer);

        IERC20(TITAN_X_ADDRESS).approve(address(infernoMinting), 1e18);
        vm.expectRevert(InfernoMinting.CycleIsOver.selector);
        infernoMinting.mint(1e18);
    }
}
