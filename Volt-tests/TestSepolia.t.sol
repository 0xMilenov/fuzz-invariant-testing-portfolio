// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

import {Volt} from "@core/Volt.sol";
import {VoltAuction} from "@core/VoltAuction.sol";
import {VoltBuyAndBurn} from "@core/VoltBuyAndBurn.sol";
import {TheVolt} from "@core/TheVolt.sol";
import {Script} from "forge-std/Script.sol";

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "@const/Constants.sol";

import {DeployVolt} from "@script/DeployVoltSepolia.s.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseTest is Test {
    Volt volt;
    VoltBuyAndBurn buyAndBurn;
    VoltAuction auction;

    address user = makeAddr("USER");

    function setUp() public {
        DeployVolt deployer = new DeployVolt();

        (volt) = deployer.run();

        auction = volt.auction();
        buyAndBurn = volt.buyAndBurn();
    }

    modifier withStartedLiquidity() {
        uint256 AMOUNT_TO_MINT = 60_000_000_000e18;

        IERC20 titanX = auction.titanX();

        deal(address(titanX), user, AMOUNT_TO_MINT);

        vm.startPrank(user);

        titanX.approve(address(auction), AMOUNT_TO_MINT);

        auction.deposit(uint192(AMOUNT_TO_MINT));

        vm.stopPrank();

        vm.prank(auction.owner());
        auction.addLiquidityToVoltTitanxPool(uint32(block.timestamp));
        _;
    }

    function test_CanBuyAndBurnSepolia() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp());
        buyAndBurn.swapTitanXForVoltAndBurn(uint32(block.timestamp));

        vm.warp(block.timestamp + 9 minutes);
        buyAndBurn.swapTitanXForVoltAndBurn(uint32(block.timestamp));

        assert(2 == buyAndBurn.lastIntervalNumber());
    }

    function test_canAccumulateForTheFirstInterval() public withStartedLiquidity {
        vm.warp(buyAndBurn.startTimeStamp() + 9 minutes);
        buyAndBurn.swapTitanXForVoltAndBurn(uint32(block.timestamp));

        assert(2 == buyAndBurn.lastIntervalNumber());
    }

    function test_everGreen() public pure {
        assert(true);
    }
}
