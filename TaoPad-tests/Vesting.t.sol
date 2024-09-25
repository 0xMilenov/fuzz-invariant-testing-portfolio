// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// INTERFACES
import {IUniswapV2Factory} from "@interfaces/IUniswapV2.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {V3Helper} from "@libs/V3Helper.sol";

// CONTRACTS
import {Presale, Token} from "@core/Presale.sol";
import {UniswapV2Connector} from "@core/connectors/UniswapV2Connector.sol";
import {UniswapV3Connector} from "@core/connectors/UniswapV3Connector.sol";

// SETUP BASE TEST
import {PresaleSetup} from "./PresaleSetup.t.sol";

contract VestingTest is PresaleSetup {
    function testTeamCannotStartVestingBeforePresaleEnds() public withCreatedPresaleUniV2(team) {
        _startPresale();

        vm.prank(team);
        vm.expectRevert();
        createdPresale.createLPAndStartVesting(block.timestamp, 1200, 0, 0);
    }

    function testIfVestingIsNotStartedClaimableAmountShouldReturn0() public withCreatedPresaleUniV2(team) {
        assert(createdPresale.getClaimableAmount(user1) == 0);
    }

    function testIsTerminatedReturnsFalsefPresaleIsNotTerminated() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        assert(createdPresale.isTerminated() == false);
    }

    function testIsTerminatedReturnsTrueIfPresaleIsTerminated() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        vm.prank(team);
        createdPresale.terminate();

        assert(createdPresale.isTerminated() == true);
    }

    function testIsTerminatedReturnsTrueIfDeadlineIsPassed() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        vm.warp(block.timestamp + 4 days);

        assert(createdPresale.isTerminated() == true);
    }

    function testTeamCanStartVestingEvenIfV2PairIsCreatedBeforehand() public withCreatedPresaleUniV2(team) {
        address attacker = makeAddr("attacker");

        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        IUniswapV2Factory uniFactory = IUniswapV2Factory(uniswapV2Connector.factory());

        address weth = uniswapV2Connector.WETH();

        vm.prank(attacker);
        address createdPair = uniFactory.createPair(weth, address(presaleToken));

        vm.startPrank(team);
        presaleToken.mint(team, 20e18);
        presaleToken.approve(address(createdPresale), 20e18);
        (address pair,) = createdPresale.createLPAndStartVesting(block.timestamp, 20e18, 0, 0);

        assert(pair == createdPair);
    }

    function testTeamCanStartVestingUniV2() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        vm.startPrank(team);
        presaleToken.mint(team, 20e18);
        presaleToken.approve(address(createdPresale), 20e18);
        createdPresale.createLPAndStartVesting(block.timestamp, 20e18, 0, 0);
    }

    function testTeamCanStartVestingUniV3() public withCreatedPresaleUniV3(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user3, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        vm.startPrank(team);
        presaleToken.mint(team, 100e18);
        presaleToken.approve(address(createdPresale), 100e18);
        createdPresale.createLPAndStartVesting(block.timestamp, 100e18, 0, 0);
    }

    function testTeamCanStartVestingUniV3IfThereIsAInitializedPoolBeforehand() public withCreatedPresaleUniV3(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user3, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        INonfungiblePositionManager univ3PositionManager = uniswapV3Connector.positionManager();

        (address token0, address token1) =
            V3Helper._sortTokens(address(presaleToken), address(uniswapV3Connector.WETH()));

        univ3PositionManager.createAndInitializePoolIfNecessary(token0, token1, 100, V3Helper.encodePriceSqrt(1, 1));

        uint256 ethBalanceWith1PercentSlippage =
            address(createdPresale).balance - (address(createdPresale).balance * 1) / 100;

        uint256 tokenBalanceWith1PercentSlippage = presaleToken.balanceOf(address(createdPresale))
            - (presaleToken.balanceOf(address(createdPresale)) * 1) / 100;

        vm.startPrank(team);
        presaleToken.mint(team, 100e18);
        presaleToken.approve(address(createdPresale), 100e18);
        vm.expectRevert("Price slippage check");
        createdPresale.createLPAndStartVesting(
            block.timestamp, 100e18, tokenBalanceWith1PercentSlippage, ethBalanceWith1PercentSlippage
        );
    }

    function testRevertsIfPriceIsLessThanActualPrice() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        vm.startPrank(team);
        presaleToken.mint(team, 101e18);
        presaleToken.approve(address(createdPresale), 101e18);
        vm.expectRevert(Presale.Presale__PriceIsHigher.selector);
        createdPresale.createLPAndStartVesting(block.timestamp, 101e18, 0, 0);
    }

    function testFactoryReceivesFeesAfterVestingIsStarted() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        uint256 feeReceiverBalanceBefore = address(feeReceiver).balance;

        vm.startPrank(team);
        presaleToken.mint(team, 20e18);
        presaleToken.approve(address(createdPresale), 20e18);
        createdPresale.createLPAndStartVesting(block.timestamp, 20e18, 0, 0);
        vm.stopPrank();

        uint256 feeReceiverBalanceAfter = address(feeReceiver).balance;

        assert(feeReceiverBalanceAfter > feeReceiverBalanceBefore);
    }

    function testUserCanWithdrawHisInvestmentAfterTerminating() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        uint256 user1BalanceBefore = user1.balance;

        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        uint256 user2BalanceBefore = user2.balance;
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        vm.prank(team);
        createdPresale.terminate();

        vm.prank(user1);
        createdPresale.withdrawNative();

        vm.prank(user2);
        createdPresale.withdrawNative();

        uint256 user1BalanceAfter = user1.balance;
        uint256 user2BalanceAfter = user2.balance;

        (, uint256 totalInvestedUser1,) = createdPresale.userRecords(user1);
        (, uint256 totalInvestedUser2,) = createdPresale.userRecords(user2);

        assert(totalInvestedUser1 == 0);
        assert(totalInvestedUser2 == 0);
        assert(user1BalanceBefore == user1BalanceAfter);
        assert(user2BalanceBefore == user2BalanceAfter);
    }

    function testClaimableAmountGrowsWithTime() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        _endPresale();

        vm.startPrank(team);
        presaleToken.mint(team, 20e18);
        presaleToken.approve(address(createdPresale), 20e18);
        createdPresale.createLPAndStartVesting(block.timestamp, 20e18, 0, 0);
        vm.stopPrank();

        (uint256 user1PurchasedAmount,,) = createdPresale.userRecords(user1);
        (uint256 user2PurchasedAmount,,) = createdPresale.userRecords(user2);

        uint256 claimableUser1AmountAtStartOfVesting = createdPresale.getClaimableAmount(user1);
        uint256 claimableUser2AmountAtStartOfVesting = createdPresale.getClaimableAmount(user2);

        assert(claimableUser1AmountAtStartOfVesting == 0);
        assert(claimableUser2AmountAtStartOfVesting == 0);

        // After half the duration of vesting
        vm.warp(block.timestamp + 1 days);

        uint256 claimableUser1AmountAfter1Day = createdPresale.getClaimableAmount(user1);
        uint256 claimableUser2AmountAfter1Day = createdPresale.getClaimableAmount(user2);

        assert(user1PurchasedAmount / 2 == claimableUser1AmountAfter1Day);
        assert(user2PurchasedAmount / 2 == claimableUser2AmountAfter1Day);

        // 1 day after vesting ended
        vm.warp(block.timestamp + 2 days);

        uint256 claimableUser1AmountAfter3Days = createdPresale.getClaimableAmount(user1);
        uint256 claimableUser2AmountAfter3Days = createdPresale.getClaimableAmount(user2);

        assert(user1PurchasedAmount == claimableUser1AmountAfter3Days);
        assert(user2PurchasedAmount == claimableUser2AmountAfter3Days);
    }
}
