// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// CONTRACTS
import {Presale} from "@core/Presale.sol";

// SETUP BASE TEST
import {PresaleSetup} from "./PresaleSetup.t.sol";

contract BuyingIntoPresaleTest is PresaleSetup {
    function testUserCanBuyOnlyAfterStart() public withCreatedPresaleUniV2(team) {
        address user = makeAddr("user");
        vm.expectRevert(Presale.Presale__NotActive.selector);
        hoax(user, 2 ether);
        createdPresale.buyTokens{value: 1 ether}();
    }

    function testUserGetsRefundedAfterExceedingMaxBuy() public withCreatedPresaleUniV2(team) {
        _startPresale();

        uint256 maxBuy = 100e18;

        uint256 maxBuyEtherPrice = createdPresale.tokenToNative(100e18);

        hoax(user1, 1 ether);
        uint256 userBalanceBefore = user1.balance;
        createdPresale.buyTokens{value: 1 ether}();

        uint256 userBalanceAfter = user1.balance;

        (uint256 purchasedAmount, uint256 investedNative,) = createdPresale.userRecords(user1);

        assert(purchasedAmount == maxBuy); // User received as much tokens as max buy
        assert(investedNative == maxBuyEtherPrice); //User has only invested as much as max buy
        assert(userBalanceAfter + maxBuyEtherPrice == userBalanceBefore); // User spend ether only for 100 tokens(maxBuy)
    }

    function testUserGetsRefundedAfterExceedingHardcap() public withCreatedPresaleUniV2(team) {
        _startPresale();

        hoax(user1, 1 ether);
        createdPresale.buyTokens{value: 0.1 ether}();

        hoax(user2, 1 ether);
        createdPresale.buyTokens{value: 0.08 ether}();

        hoax(user3, 1 ether);
        uint256 userBalanceBefore = user3.balance;
        createdPresale.buyTokens{value: 0.04 ether}();

        uint256 expectedPurchasedAmount = createdPresale.nativeToToken(0.02 ether);
        uint256 expectedInvestedAmount = createdPresale.tokenToNative(expectedPurchasedAmount);

        uint256 userBalanceAfter = user3.balance;

        (uint256 purchasedAmount, uint256 investedNative,) = createdPresale.userRecords(user3);

        assert(purchasedAmount == expectedPurchasedAmount); // User received as much tokens as hardcap
        assert(investedNative == expectedInvestedAmount); //User has only invested as much as hardcap
        assert(userBalanceAfter + 0.02 ether == userBalanceBefore); // User spend ether only for 20 tokens and getting refunded the  rest (20)
    }

    function testUserCanBuyAfterStart() public withCreatedPresaleUniV2(team) {
        address user = makeAddr("user");

        _startPresale();
        uint256 amountToInvest = 0.04 ether;
        uint256 expectedAmountBought = createdPresale.nativeToToken(amountToInvest);

        hoax(user, 2 ether);
        createdPresale.buyTokens{value: amountToInvest}();

        (uint256 purchasedAmount, uint256 investedNative, uint256 claimedAmount) = createdPresale.userRecords(user);

        assert(amountToInvest == investedNative);
        assert(purchasedAmount == expectedAmountBought);
        assert(claimedAmount == 0);
    }

    function testUserCannotWithdrawBeforeTerminating() public withCreatedPresaleUniV2(team) {
        address user = makeAddr("user");

        _startPresale();
        hoax(user, 2 ether);
        createdPresale.buyTokens{value: 0.04 ether}();

        vm.expectRevert(Presale.Presale__NotTerminated.selector);
        createdPresale.withdrawNative();
    }

    function testUserCannotBuyAfterPresaleIsEnded() public withCreatedPresaleUniV2(team) {
        address user = makeAddr("user");

        _endPresale();
        hoax(user, 2 ether);
        vm.expectRevert(Presale.Presale__NotActive.selector);
        createdPresale.buyTokens{value: 0.04 ether}();
    }
}
