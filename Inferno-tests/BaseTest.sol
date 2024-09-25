// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

import {Inferno} from "../src/Inferno.sol";
import {InfernoMinting} from "../src/InfernoMinting.sol";
import {InfernoBuyAndBurn} from "../src/InfernoBuyAndBurn.sol";
import {DeployInferno} from "../script/DeployInferno.sol";

contract BaseTest is Test {
    Inferno inferno;
    InfernoBuyAndBurn infernoBuyAndBurn;
    InfernoMinting infernoMinting;

    function setUp() public {
        DeployInferno deployer = new DeployInferno();

        (inferno, infernoMinting, infernoBuyAndBurn) = deployer.run();
    }

    function test_wireUp() public view {
        assert(address(infernoMinting.inferno()) == address(inferno));
        assert(address(infernoBuyAndBurn.infernoToken()) == address(inferno));
        assert(address(inferno.minting()) == address(infernoMinting));
        assert(address(inferno.buyAndBurn()) == address(infernoBuyAndBurn));
    }

    function test_everGreen() public pure {
        assert(true);
    }
}
