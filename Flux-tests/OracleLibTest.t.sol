// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {OracleLibrary} from "../src/libs/OracleLibrary.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract OracleLibraryTest is Test {
    IUniswapV3Pool pool;
    address poolAddress;

    function setUp() public {
        poolAddress = address(0x123456); // Mock pool address
        pool = IUniswapV3Pool(poolAddress);
    }

    function testConsultFunction() public {
        // Mock the behavior of the IUniswapV3Pool's observe function
        int56[] memory tickCumulatives = new int56[](2);
        tickCumulatives[0] = 0;
        tickCumulatives[1] = 100;

        uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
        secondsPerLiquidityCumulativeX128s[0] = 0;
        secondsPerLiquidityCumulativeX128s[1] = 100;

        bytes4 selector = bytes4(keccak256("observe(uint32[])"));
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 10;
        secondsAgos[1] = 0;

        vm.mockCall(
            poolAddress,
            abi.encodeWithSelector(selector, secondsAgos),
            abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
        );

        (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity) = OracleLibrary.consult(poolAddress, 10);

        // Calculated expected values
        int24 expectedArithmeticMeanTick = 10; // (tickCumulatives[1] - tickCumulatives[0]) / 10
        uint128 expectedHarmonicMeanLiquidity =
            uint128((uint192(10) * uint192(type(uint160).max)) / (uint192(100) << 32));

        assertEq(arithmeticMeanTick, expectedArithmeticMeanTick, "Arithmetic mean tick mismatch");
        assertEq(harmonicMeanLiquidity, expectedHarmonicMeanLiquidity, "Harmonic mean liquidity mismatch");
    }

    function testGetOldestObservationSecondsAgo() public {
        uint32 blockTimestamp = uint32(block.timestamp);

        bytes4 slot0Selector = bytes4(keccak256("slot0()"));
        bytes4 observationsSelector = bytes4(keccak256("observations(uint256)"));

        // Mock the behavior of the IUniswapV3Pool's slot0 and observations functions
        vm.mockCall(poolAddress, abi.encodeWithSelector(slot0Selector), abi.encode(0, 0, 0, 1, 0, 0, 0));

        vm.mockCall(
            poolAddress, abi.encodeWithSelector(observationsSelector, 0), abi.encode(blockTimestamp - 100, 0, 0, true)
        );

        uint32 secondsAgo = OracleLibrary.getOldestObservationSecondsAgo(poolAddress);

        assertEq(secondsAgo, 100, "Oldest observation seconds ago mismatch");
    }

    function testGetQuoteForSqrtRatioX96() public pure {
        uint160 sqrtRatioX96 = 79228162514264337593543950336; // 2^96
        uint256 baseAmount = 1e18; // 1 token
        address baseToken = address(0x123);
        address quoteToken = address(0x456);

        uint256 quoteAmount = OracleLibrary.getQuoteForSqrtRatioX96(sqrtRatioX96, baseAmount, baseToken, quoteToken);

        uint256 expectedQuoteAmount = Math.mulDiv(uint256(sqrtRatioX96) * sqrtRatioX96, baseAmount, 1 << 192);
        assertEq(quoteAmount, expectedQuoteAmount, "Quote amount mismatch");
    }

    function testGetQuoteForSqrtRatioX96WithOverflow() public pure {
        uint160 sqrtRatioX96 = type(uint160).max;
        uint256 baseAmount = 1e18; // 1 token
        address baseToken = address(0x123);
        address quoteToken = address(0x456);

        uint256 ratioX128 = Math.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
        uint256 expectedQuoteAmount = Math.mulDiv(ratioX128, baseAmount, 1 << 128);

        uint256 quoteAmount = OracleLibrary.getQuoteForSqrtRatioX96(sqrtRatioX96, baseAmount, baseToken, quoteToken);

        assertEq(quoteAmount, expectedQuoteAmount, "Quote amount mismatch with overflow sqrtRatioX96");
    }

    function testGetQuoteForSqrtRatioX96WhenBaseTokenIsGreaterThanQuoteToken() public pure {
        uint160 sqrtRatioX96 = 79228162514264337593543950336; // 2^96
        uint256 baseAmount = 1e18; // 1 token
        address baseToken = address(0x456);
        address quoteToken = address(0x123);

        uint256 quoteAmount = OracleLibrary.getQuoteForSqrtRatioX96(sqrtRatioX96, baseAmount, baseToken, quoteToken);

        uint256 expectedQuoteAmount = Math.mulDiv(1 << 192, baseAmount, uint256(sqrtRatioX96) * sqrtRatioX96);
        assertEq(quoteAmount, expectedQuoteAmount, "Quote amount mismatch when baseToken is greater than quoteToken");
    }
}
