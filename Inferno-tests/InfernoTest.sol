// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseTest} from "./BaseTest.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/const/BuyAndBurnConst.sol";

import {InfernoMinting} from "../src/InfernoMinting.sol";
import {Inferno} from "../src/Inferno.sol";

contract InfernoTest is BaseTest {
    address mintTo = makeAddr("mintTo");

    function test_OnlyMinterCanMint() public {
        vm.expectRevert(Inferno.OnlyMinting.selector);
        inferno.mint(msg.sender, 1000e18);
    }

    function test_WireUp() public view {
        assert(address(inferno.minting()) == address(infernoMinting));
        assert(address(inferno.buyAndBurn()) == address(infernoBuyAndBurn));
    }

    function test_OnlyBuyAndBurnCanMintForLiquidity() public {
        vm.expectRevert(Inferno.OnlyBuyAndBurn.selector);
        inferno.mintTokensForLP();
    }

    function test_canBurnTokens() public {
        uint256 AMOUNT_TO_MINT = 100e18;
        vm.prank(address(inferno.minting()));
        inferno.mint(mintTo, AMOUNT_TO_MINT);

        assert(inferno.balanceOf(mintTo) == AMOUNT_TO_MINT);

        vm.prank(mintTo);
        inferno.burn(AMOUNT_TO_MINT);

        assert(inferno.balanceOf(mintTo) == 0);
    }

    function test_CanMint() public {
        uint256 AMOUNT_TO_MINT = 100e18;
        vm.prank(address(inferno.minting()));
        inferno.mint(mintTo, AMOUNT_TO_MINT);

        assert(inferno.balanceOf(mintTo) == AMOUNT_TO_MINT);
    }

    function test_canMintTokensForLp() public {
        assert(inferno.balanceOf(address(inferno.buyAndBurn())) == 0);

        vm.prank(address(inferno.buyAndBurn()));
        inferno.mintTokensForLP();

        assert(inferno.balanceOf(address(inferno.buyAndBurn())) == INITIAL_LP_MINT);
    }
}
