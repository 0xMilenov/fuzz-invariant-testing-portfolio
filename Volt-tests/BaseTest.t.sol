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

import {DeployVolt} from "@script/DeployVolt.s.sol";

contract BaseTest is Test {
    DeployVolt deployer;
    address user = makeAddr("user");

    Volt volt;
    VoltAuction auction;
    VoltBuyAndBurn buyAndBurn;
    TheVolt theVolt;

    function setUp() public {
        deployer = new DeployVolt();

        volt = deployer.run();

        auction = volt.auction();
        buyAndBurn = volt.buyAndBurn();
        theVolt = volt.theVolt();
    }

    function _depositFor(address _user, uint160 _amount) internal {
        deal(address(TITAN_X), _user, _amount);

        vm.startPrank(_user);
        TITAN_X.approve(address(auction), _amount);
        auction.deposit(_amount);
        vm.stopPrank();
    }

    function _moveToStart() internal {
        uint32 startTimestamp = auction.startTimestamp();

        vm.warp(startTimestamp);
    }

    function _addLiquidity() internal {
        _moveToStart();

        _depositFor(makeAddr("TEST"), INITIAL_TITAN_X_FOR_LIQ);

        vm.prank(auction.owner());
        auction.addLiquidityToVoltTitanxPool(uint32(block.timestamp));
    }

    modifier withStartedLiquidity() {
        _addLiquidity();

        _depositFor(makeAddr("TEST"), 100_000e18);

        _;
    }

    function test_green() public pure {
        assert(true);
    }
}
