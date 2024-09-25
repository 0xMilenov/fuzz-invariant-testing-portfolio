// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./BaseTest.t.sol";

import "@const/Constants.sol";

contract StakingTest is BaseTest {
    function testUserCanStake() external {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 10e18);

        vm.startPrank(user);
        flux.approve(address(staking), 10e18);
        staking.stake(staking.MIN_DURATION(), 10e18);

        (uint160 shares, uint160 _flux,,) = staking.userRecords(1);

        assert(shares == _flux);
        assert(flux.balanceOf(address(staking)) == _flux);
    }

    function testShareRateDropsWeekly() external {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 100e18);

        vm.startPrank(user);
        flux.approve(address(staking), 10e18);
        staking.stake(staking.MIN_DURATION(), 10e18);

        (uint160 shares, uint160 _flux,,) = staking.userRecords(1);

        assert(shares == _flux);
        assert(flux.balanceOf(address(staking)) == _flux);

        vm.warp(block.timestamp + 8 days);

        flux.approve(address(staking), 10e18);
        staking.stake(staking.MIN_DURATION(), 10e18);

        assert(staking.getFluxToShareRatio() == 1012760785902369860);
    }

    function testGetsAddedToVoluntaryForMaxStake() external {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 100e18);

        vm.startPrank(user);
        flux.approve(address(staking), 10e18);
        staking.stake(staking.MAX_DURATION(), 10e18);

        (uint160 shares, uint160 _flux,,) = staking.userRecords(1);

        assert(shares == _flux);
        assert(flux.balanceOf(address(staking)) == _flux);

        Voluntary777Pool voluntary = staking.voluntary();

        (uint144 voluntaryShares,) = voluntary.record(1);

        assert(voluntaryShares == shares);
    }

    function testCannotUnstakeBeforeDuration() external {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 100e18);

        vm.startPrank(user);
        flux.approve(address(staking), 10e18);
        staking.stake(staking.MAX_DURATION(), 10e18);

        vm.expectRevert(FluxStaking.FluxStaking__LockPeriodNotOver.selector);
        staking.unstake(1, user);
    }

    function testDistributesRewardsOnlyForCertainDays() external {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 100e18);
        deal(address(TITAN_X), user, 100e18);

        vm.startPrank(user);

        flux.approve(address(staking), 10e18);
        staking.stake(staking.MAX_DURATION(), 10e18);

        TITAN_X.approve(address(staking), 100e18);
        staking.distribute(100e18);

        assert(staking.rewardPerShare() == 0);
    }

    function testDistributes38PercentFor8Daypool() external {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 38e18);
        deal(address(TITAN_X), user, 100e18);

        vm.startPrank(user);

        flux.approve(address(staking), 38e18);
        staking.stake(staking.MAX_DURATION(), 38e18);

        vm.warp(block.timestamp + 6 days);

        TITAN_X.approve(address(staking), 100e18);
        staking.distribute(100e18);

        assert(staking.rewardPerShare() == 1e18);
    }

    function testUserDoesNotReceiveRewardsFromPrevDistributions() external {
        _addLiquidity();
        address user2 = makeAddr("user2");

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 20e18);
        deal(address(TITAN_X), user, 200e18);

        vm.startPrank(user);
        flux.approve(address(staking), 20e18);
        staking.stake(staking.MAX_DURATION(), 20e18);

        vm.warp(block.timestamp + 7 days);

        TITAN_X.approve(address(staking), 200e18);
        staking.distribute(200e18);

        vm.stopPrank();

        deal(address(flux), user2, 20e18);
        vm.startPrank(user2);

        flux.approve(address(staking), 20e18);
        staking.stake(staking.MAX_DURATION(), 20e18);

        staking.claim(2, user2);

        assert(TITAN_X.balanceOf(user2) == 0);
    }

    function test_batchClaimableAmountReturnsCorrect() public {
        vm.warp(staking.startTimestamp());

        deal(address(flux), user, 20e18);
        deal(address(TITAN_X), user, 200e18);

        vm.startPrank(user);
        flux.approve(address(staking), 20e18);
        staking.stake(staking.MAX_DURATION(), 20e18);

        TITAN_X.approve(address(staking), 200e18);
        staking.distribute(200e18);

        vm.warp(block.timestamp + 8 days);

        uint160[] memory _ids = new uint160[](1);

        _ids[0] = 1;

        assert(staking.batchClaimableAmount(_ids) == 200e18);
    }

    function testCannotTransferStake() public {
        _addLiquidity();
        address user2 = makeAddr("user2");

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 20e18);

        vm.startPrank(user);
        flux.approve(address(staking), 20e18);
        staking.stake(staking.MAX_DURATION(), 20e18);

        vm.expectRevert(FluxStaking.FluxStaking__OnlyMintingAndBurning.selector);
        staking.transferFrom(user, user2, 1);
    }

    function testCanUnstakeAfterTime() public {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        deal(address(flux), user, 20e18);

        vm.startPrank(user);
        flux.approve(address(staking), 20e18);
        staking.stake(staking.MAX_DURATION(), 20e18);

        vm.warp(block.timestamp + staking.MAX_DURATION());

        staking.unstake(1, user);

        assert(flux.balanceOf(user) == 20e18);
    }

    function testUserCannotUnstakeAutoBuyAndMaxStakes() public {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        _depositFor(user, 100e18);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user);
        auction.claim(2);

        vm.warp(block.timestamp + staking.MAX_DURATION());

        vm.expectRevert(FluxStaking.FluXStaking__CannotUnstakeAutoBoughtAndStakedFlux.selector);
        staking.unstake(1, user);
    }

    function testUserCanClaimFromAutoBuyAndStake() public {
        _addLiquidity();

        vm.warp(block.timestamp + 24 hours);

        _depositFor(user, 100e18);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user);
        auction.claim(2);

        vm.warp(block.timestamp + 6 days);

        vm.startPrank(user);
        deal(address(TITAN_X), user, 100e18);
        TITAN_X.approve(address(staking), 100e18);
        staking.distribute(100e18);

        staking.claim(1, user);

        assertApproxEqAbs(TITAN_X.balanceOf(user), 45.6e18, 100);
    }

    function testUserCanClaimFromVoluntaryPool() public {
        _addLiquidity();
        address user2 = makeAddr("user2");

        vm.warp(block.timestamp + 24 hours);

        _depositFor(user, 100e18);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user);
        auction.claim(2);

        vm.startPrank(user2);
        deal(address(flux), user2, 50e18);
        flux.approve(address(staking), 50e18);
        staking.stake(staking.MAX_DURATION(), 50e18);

        vm.warp(block.timestamp + 776 days);

        vm.stopPrank();

        vm.startPrank(user);
        deal(address(TITAN_X), user, 100e18);

        TITAN_X.approve(address(staking), 100e18);
        staking.distribute(100e18);

        staking.claim(1, user);

        vm.stopPrank();

        vm.prank(user2);
        staking.claim(2, user2);

        assertApproxEqAbs(TITAN_X.balanceOf(user), 107999999775000000000, 100);
        assertApproxEqAbs(TITAN_X.balanceOf(user2), 12000000071999999850, 100);
    }
}
