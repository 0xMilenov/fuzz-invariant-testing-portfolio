// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

import {Inferno} from "../src/Inferno.sol";
import {InfernoMinting} from "../src/InfernoMinting.sol";
import {InfernoBuyAndBurn} from "../src/InfernoBuyAndBurn.sol";
import {DeployInferno} from "../script/DeployInfernoSepolia.sol";

contract BaseTest is Test {
    Inferno inferno;
    InfernoBuyAndBurn infernoBuyAndBurn;
    InfernoMinting infernoMinting;

    function setUp() public {
        DeployInferno deployer = new DeployInferno();

        (inferno, infernoMinting, infernoBuyAndBurn) = deployer.run();
    }

    function test_CanBuyAndBurn() public {
        vm.warp(infernoBuyAndBurn.startTimeStamp());
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        vm.warp(block.timestamp + 700);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        assert(2 == infernoBuyAndBurn.lastIntervalNumber());
    }

    function test_canAccumulateForTheFirstInterval() public {
        vm.warp(block.timestamp + 1800);
        infernoBuyAndBurn.swapTitanXForInfernoAndBurn(0, uint32(block.timestamp));

        assert(2 == infernoBuyAndBurn.lastIntervalNumber());
    }

    function test_everGreen() public pure {
        assert(true);
    }
}
