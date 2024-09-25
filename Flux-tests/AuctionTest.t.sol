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
        vm.expectRevert(FluxAuction.FluxAuction__NotStartedYet.selector);
        auction.deposit(1e18);
    }

    function testEmits75BInitially() external {
        _moveToStart();
        _depositFor(user, 10e18);

        assert(flux.balanceOf(address(auction)) == AUCTION_EMIT);
    }

    function testCannotClaimBefore24Hours() external {
        _moveToStart();
        _depositFor(user, 10e18);

        vm.warp(block.timestamp + 6 hours);
        vm.prank(user);
        vm.expectRevert(FluxAuction.FluxAuction__OnlyClaimableAfter24Hours.selector);
        auction.claim(1);
    }

    function testClaimsAllAfter24Hours() external {
        _moveToStart();
        _depositFor(user, 10e18);

        vm.warp(block.timestamp + 25 hours);
        vm.prank(user);

        auction.claim(1);

        assert(flux.balanceOf(user) == AUCTION_EMIT);
    }

    function testDistributesProportionalAmountFlux() external {
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
        auction.claim(2);

        vm.prank(user3);
        auction.claim(3);

        assert(flux.balanceOf(user) == AUCTION_EMIT / 2);
        assert(flux.balanceOf(user2) == (AUCTION_EMIT / 2) / 2);
        assert(flux.balanceOf(user3) == (AUCTION_EMIT / 2) / 2);
    }

    function testForDistributionIsUpdatedEvenWithoutLp() public {
        _moveToStart();
        _depositFor(user, INITIAL_TITAN_X_FOR_LIQ + 500e18);
    }

    function testIfDistributedBeforeThatWeStillHaveForLiquidity() public {
        _moveToStart();
        _depositFor(user, INITIAL_TITAN_X_FOR_LIQ + 500e18);

        assert(TITAN_X.balanceOf(address(auction)) == INITIAL_TITAN_X_FOR_LIQ);
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
        vm.expectRevert(FluxAuction.FluxAuction__NothingToClaim.selector);
        auction.claim(1);

        vm.prank(user2);
        auction.claim(2);

        assert(flux.balanceOf(user) == AUCTION_EMIT / 2);
        assert(flux.balanceOf(user2) == AUCTION_EMIT / 2);
    }

    function testEmissionDropsEveryWeek() public {
        _moveToStart();

        _depositFor(user, INITIAL_TITAN_X_FOR_LIQ);

        vm.prank(auction.owner());
        auction.addLiquidityToInfernoFluxPool(uint32(block.timestamp));

        vm.warp(block.timestamp + 1 weeks + 1 hours);

        _depositFor(user, 10e18);

        vm.warp(block.timestamp + 24 hours);

        vm.prank(user);
        auction.claim(2);

        assert(flux.balanceOf(user) == 75_000_000_000e18 - (75_000_000_000e18 * 0.012e18) / 1e18);
    }

    function testCanStartLiquidity() public {
        _addLiquidity();
    }

    function testDoesNotMaxBuyAndStakeOnTheFirstDay() public {
        _moveToStart();

        _depositFor(user, INITIAL_TITAN_X_FOR_LIQ);

        vm.warp(block.timestamp + 24 hours);

        vm.prank(user);
        auction.claim(1);

        assert(flux.balanceOf(user) == 75_000_000_000e18);
    }

    function testAutoBuyAndMaxStake() public {
        _moveToStart();

        _depositFor(user, INITIAL_TITAN_X_FOR_LIQ);

        vm.prank(auction.owner());
        auction.addLiquidityToInfernoFluxPool(uint32(block.timestamp));

        vm.warp(block.timestamp + 24 hours);

        _depositFor(user, 10e18);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user);
        auction.claim(2);

        (uint160 shares,,, uint32 endTime) = staking.userRecords(1);

        assert(endTime == block.timestamp + staking.MAX_DURATION());
        assert(shares == flux.balanceOf(address(staking)));
    }
}
