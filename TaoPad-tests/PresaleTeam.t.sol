// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// CONTRACTS
import {Presale} from "@core/Presale.sol";

// SETUP BASE TEST
import {PresaleSetup} from "./PresaleSetup.t.sol";

contract PresaleTeamTest is PresaleSetup {
    function testRevertsIfOtherUserTriesToUpdateMetadata() public withCreatedPresaleUniV2(team) {
        vm.expectRevert();
        vm.prank(user1);
        createdPresale.updatePresaleMetaData("new link");
    }

    function test() public withCreatedPresaleUniV2(team) {
        string memory newMeta = "new link";

        vm.prank(team);
        createdPresale.updatePresaleMetaData(newMeta);

        assert(keccak256(abi.encode(newMeta)) == keccak256(abi.encode(createdPresale.meta())));
    }

    function testDurationIsCorrect() public withCreatedPresaleUniV2(team) {
        uint256 _duration = createdPresale.getDuration();

        assert(_duration == 7 days);
    }

    function testUniswapV2WireUp() public {
        (address _uniswapV2Factory, address _uniswapV2Router,, address _weth,) = deployer.config();

        assert(address(uniswapV2Connector.router()) == _uniswapV2Router);
        assert(uniswapV2Connector.WETH() == _weth);
        assert(address(uniswapV2Connector.factory()) == _uniswapV2Factory);
    }

    function testUniswapV3WireUp() public {
        (,, address _uniswapV3PositionManager, address _weth, address _quoter) = deployer.config();

        assert(address(uniswapV3Connector.quoter()) == _quoter);
        assert(address(uniswapV3Connector.positionManager()) == _uniswapV3PositionManager);
        assert(uniswapV3Connector.WETH() == _weth);
    }

    function testTeamCanChangeConnector() public withCreatedPresaleUniV2(team) {
        vm.prank(team);
        createdPresale.changeConnector(address(uniswapV3Connector));

        assert(address(createdPresale.connector()) == address(uniswapV3Connector));
    }

    function testRevertsIfTryingToChangePricePerTokenAfterStart() public withCreatedPresaleUniV2(team) {
        _startPresale();

        vm.expectRevert(Presale.Presale__AlreadyStarted.selector);
        vm.prank(team);
        createdPresale.updateEthPricePerToken(2 ether);
    }

    function testTeamCanChangePricePerTokenBeforeStart() public withCreatedPresaleUniV2(team) {
        vm.prank(team);
        createdPresale.updateEthPricePerToken(2 ether);

        assert(createdPresale.ethPricePerToken() == 2 ether);
    }

    function testTeamCanIncreaseHardCapBeforeEnding() public withCreatedPresaleUniV2(team) {
        _startPresale();

        presaleToken.mint(team, 20e18);

        vm.startPrank(team);
        presaleToken.approve(address(createdPresale), 20e18);
        createdPresale.increaseHardCap(20e18);

        _endPresale();

        vm.expectRevert(Presale.Presale__AlreadyEnded.selector);
        createdPresale.increaseHardCap(20e18);
    }
}
