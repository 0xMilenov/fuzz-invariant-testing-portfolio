// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./BaseTest.t.sol";

import "@const/Constants.sol";

contract AuctionTest is BaseTest {
    function testCannotAuctionBeforeStart() external {
        deal(address(TITAN_X), user, 10000000e18);

        vm.warp(block.timestamp - 30);

        vm.startPrank(user);
        TITAN_X.approve(address(auction), 1e18);
        vm.expectRevert(VoltAuction.VoltAuction__NotStartedYet.selector);
        auction.deposit(1e18);
    }

    function testEmits100MInitially() external {
        _moveToStart();
        _depositFor(user, 10e18);

        assert(volt.balanceOf(address(auction)) == AUCTION_EMIT);
    }

    function testCannotClaimBefore24Hours() external {
        _moveToStart();
        _depositFor(user, 10e18);

        vm.warp(block.timestamp + 6 hours);
        vm.prank(user);
        vm.expectRevert(VoltAuction.VoltAuction__OnlyClaimableTheNextDay.selector);
        auction.claim(1);
    }

    function testClaimsAllAfter24Hours() external {
        _moveToStart();
        _depositFor(user, 10e18);

        vm.warp(block.timestamp + 25 hours);
        vm.prank(user);

        auction.claim(1);

        assert(volt.balanceOf(user) == AUCTION_EMIT);
    }

    function testDistributesProportionalAmountvolt() external {
        _moveToStart();
        address user2 = makeAddr("User2");
        address user3 = makeAddr("User3");

        _depositFor(user, 10e18);
        _depositFor(user2, 5e18);
        _depositFor(user3, 5e18);

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user);
        auction.claim(1);

        vm.prank(user2);
        auction.claim(1);

        vm.prank(user3);
        auction.claim(1);

        assert(volt.balanceOf(user) == AUCTION_EMIT / 2);
        assert(volt.balanceOf(user2) == (AUCTION_EMIT / 2) / 2);
        assert(volt.balanceOf(user3) == (AUCTION_EMIT / 2) / 2);
    }

    function testUserCannotClaimTwice() external {
        _moveToStart();
        address user2 = makeAddr("User2");

        _depositFor(user, 10e18);
        _depositFor(user2, 10e18);

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user);
        auction.claim(1);

        vm.prank(user);
        vm.expectRevert(VoltAuction.VoltAuction__NothingToClaim.selector);
        auction.claim(1);

        vm.prank(user2);
        auction.claim(1);

        assert(volt.balanceOf(user) == AUCTION_EMIT / 2);
        assert(volt.balanceOf(user2) == AUCTION_EMIT / 2);
    }

    function testForDistributionIsUpdatedEvenWithoutLp() public {
        _moveToStart();
        _depositFor(user, INITIAL_TITAN_X_FOR_LIQ + 500e18);

        assert(TITAN_X.balanceOf(address(auction)) == INITIAL_TITAN_X_FOR_LIQ);
    }

    function test_totalSupplyIsCapped() public {
        // 1
        _moveToStart();
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 100_000_000e18 + 50_000_000e18);

        // 2
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 200_000_000e18 + 50_000_000e18);

        // 3
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 300_000_000e18 + 50_000_000e18);

        // 4
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 400_000_000e18 + 50_000_000e18);

        // 5
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 500_000_000e18 + 50_000_000e18);

        // 6
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 600_000_000e18 + 50_000_000e18);

        // 7
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 700_000_000e18 + 50_000_000e18);

        // 8
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 800_000_000e18 + 50_000_000e18);

        // 9
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 900_000_000e18 + 50_000_000e18);

        // 10
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        (uint128 voltEmitted, uint128 titanXDeposited) = auction.dailyStats(10);

        assert(voltEmitted == 100_000_000e18);
        assert(titanXDeposited == 10e18);
        assert(volt.totalSupply() == 1_000_000_000e18 + 50_000_000e18);
    }

    function test_AfterDay10WeEmitFromTheVolt() public withStartedLiquidity {
        // 1
        _moveToStart();
        _depositFor(user, 10e18);

        assert(volt.totalSupply() == 100_000_000e18 + 55_000_000e18);

        // 2
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        // 3
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 1000e18);

        // 4
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        // 5
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        // 6
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        // 7
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        // 8
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        buyAndBurn.swapTitanXForVoltAndBurn(type(uint32).max);

        // 9
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        // 10
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        (uint128 voltEmitted, uint128 titanXDeposited) = auction.dailyStats(10);

        assert(voltEmitted == 100_000_000e18);
        assert(titanXDeposited == 10e18);

        uint256 fluxInTheVolt = volt.balanceOf(address(theVolt));
        // 11
        vm.warp(block.timestamp + 1 days);
        _depositFor(user, 10e18);

        (uint128 voltEmitted1,) = auction.dailyStats(11);

        assert(voltEmitted1 == (fluxInTheVolt * 0.2e18) / 1e18);
    }

    function testCanStartLiquidity() public {
        _addLiquidity();
    }
}
