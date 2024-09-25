// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// SETUP BASE TEST
import {PresaleSetup} from "./PresaleSetup.t.sol";

contract FactoryTest is PresaleSetup {
    ////////////////
    //  FACTORY  //

    function testHasValidOwner() public view {
        assert(factory.owner() == owner);
    }

    function testOwnerCanChangeStakeholderFee() public {
        uint256 currentStakeholderFee = factory.presaleFee();

        vm.prank(owner);
        factory.changePresaleFee(1e15);

        uint256 newFee = factory.presaleFee();

        assert(newFee != currentStakeholderFee);
        assert(newFee == 1e15);
    }

    function testPresaleAtIndex() public withCreatedPresaleUniV2(team) {
        assert(factory.getPresaleAtIndex(0) == address(createdPresale));
    }

    function testPresalesLength() public {
        vm.startPrank(team);

        assert(factory.presalesLength() == 0);
        _createPresale(address(uniswapV2Connector));
        assert(factory.presalesLength() == 1);
    }

    function testTeamCanCreatePresale() public withCreatedPresaleUniV2(team) {
        assert(factory.isPresale(address(createdPresale)));
    }
}
