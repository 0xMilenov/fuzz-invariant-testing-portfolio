// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

import {Flux} from "@core/Flux.sol";
import {FluxStaking} from "@core/Staking.sol";
import {FluxAuction} from "@core/FluxAuction.sol";
import {FluxBuyAndBurn} from "@core/FluxBuyAndBurn.sol";
import {Voluntary777Pool} from "@core/Pools/777Voluntary.sol";

import {Script} from "forge-std/Script.sol";

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "@const/Constants.sol";

import {DeployFlux} from "@script/DeployFlux.s.sol";

contract BaseTest is Test {
    DeployFlux deployer;
    address user = makeAddr("user");

    Flux flux;
    FluxStaking staking;
    FluxAuction auction;
    FluxBuyAndBurn buyAndBurn;

    function setUp() public {
        deployer = new DeployFlux();

        flux = deployer.run();

        auction = flux.auction();
        buyAndBurn = flux.buyAndBurn();
        staking = flux.staking();
    }

    function _depositFor(address _user, uint160 _amount) internal {
        deal(address(TITAN_X), _user, _amount);

        vm.startPrank(_user);
        TITAN_X.approve(address(auction), _amount);
        auction.deposit(_amount);
        vm.stopPrank();
    }

    function _moveToStart() internal {
        vm.warp(auction.startTimestamp());
    }

    function _addLiquidity() internal {
        _moveToStart();

        _depositFor(makeAddr("TEST"), INITIAL_TITAN_X_FOR_LIQ);

        vm.prank(auction.owner());
        auction.addLiquidityToInfernoFluxPool(uint32(block.timestamp));
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
