// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// INTERFACES
import {IUniswapV2Factory, IUniswapV2Pair, IUniswapV2Router02} from "@interfaces/IUniswapV2.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {V3Helper} from "@libs/V3Helper.sol";

// CONTRACTS
import {Presale, Token} from "@core/Presale.sol";
import {PresaleFeeReceiver} from "@core/PresaleFeeReceiver.sol";
import {PresaleFactory} from "@core/PresaleFactory.sol";
import {UniswapV2Connector} from "@core/connectors/UniswapV2Connector.sol";
import {UniswapV3Connector} from "@core/connectors/UniswapV3Connector.sol";

// FORGE
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// SCRIPTS
import {DeployPresaleFactory} from "@script/DeployPresaleFactory.s.sol";

// MOCKS
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract PresaleSetup is Test {
    DeployPresaleFactory deployer;
    PresaleFactory factory;
    PresaleFeeReceiver feeReceiver;
    UniswapV2Connector uniswapV2Connector;
    UniswapV3Connector uniswapV3Connector;

    address owner = makeAddr("owner");
    address team = makeAddr("team");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    ERC20Mock presaleToken; // Shadow variable
    uint32 presaleStartDate; // Shadow variable
    uint32 presaleEndDate; // Shadow variable
    Presale createdPresale; // Shadow variable

    function setUp() public {
        deployer = new DeployPresaleFactory();

        (address presaleFactory, address presaleFeeReceiver, address v2Connector, address v3Connector) =
            deployer.deploy(owner);

        factory = PresaleFactory(presaleFactory);
        feeReceiver = PresaleFeeReceiver(payable(presaleFeeReceiver));
        uniswapV2Connector = UniswapV2Connector(v2Connector);
        uniswapV3Connector = UniswapV3Connector(v3Connector);
    }

    function _createPresale(address _connector) internal {
        string memory meta = "ipfs://<cid>/<path>";

        presaleStartDate = uint32(block.timestamp) + 2 days;
        uint32 duration = 7 days;
        presaleEndDate = presaleStartDate + duration;

        presaleToken = new ERC20Mock();

        uint256 initialHardCap = 200e18;

        createdPresale = factory.createPresale(
            meta, address(presaleToken), 0.001 ether, presaleStartDate, duration, 30e18, 100e18, 2 days, _connector
        );

        presaleToken.mint(team, initialHardCap);

        presaleToken.approve(address(createdPresale), initialHardCap);

        createdPresale.increaseHardCap(initialHardCap);
    }

    modifier withCreatedPresaleUniV2(address creator) {
        vm.startPrank(creator);
        _createPresale(address(uniswapV2Connector));
        vm.stopPrank();
        _;
    }

    modifier withCreatedPresaleUniV3(address creator) {
        vm.startPrank(creator);
        _createPresale(address(uniswapV3Connector));
        vm.stopPrank();
        _;
    }

    function _startPresale() internal {
        vm.warp(presaleStartDate);
    }

    function _endPresale() internal {
        vm.warp(presaleEndDate);
    }
}
