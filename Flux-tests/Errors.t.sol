// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "@utils/Errors.sol";

// Exposing the internal functions for testing
contract ErrorsExposed is Errors {
    function exposed_notAddress0(address a) public pure {
        _notAddress0(a);
    }

    function exposed_notAmount0(uint256 a) public pure {
        _notAmount0(a);
    }

    function NotExpired(uint32 deadline) public notExpired(deadline) {
        // This function will succeed or revert based on the modifier
    }
}

contract ErrorsTest is Test {
    ErrorsExposed errorsContract;

    function setUp() public {
        errorsContract = new ErrorsExposed();
    }

    function testNotAddress0_RevertsOnZeroAddress() public {
        // Expect the NotAddress0 error to be thrown when address(0) is passed
        vm.expectRevert(Errors.Address0.selector);
        errorsContract.exposed_notAddress0(address(0));
    }

    function testNotAddress0_SucceedsOnNonZeroAddress() public view {
        // Should not revert for non-zero address
        errorsContract.exposed_notAddress0(address(1));
    }

    function testNotAmount0_RevertsOnZeroAmount() public {
        // Expect the Not0Amount0 error to be thrown when 0 is passed
        vm.expectRevert(Errors.Amount0.selector);
        errorsContract.exposed_notAmount0(0);
    }

    function testNotAmount0_SucceedsOnNonZeroAmount() public view {
        // Should not revert for non-zero amount
        errorsContract.exposed_notAmount0(1);
    }

    function testNotExpired_RevertsOnExpiredDeadline() public {
        uint32 pastDeadline = uint32(block.timestamp - 1);

        // Expect the Expired error to be thrown for a past deadline
        vm.expectRevert(Errors.Expired.selector);
        errorsContract.NotExpired(pastDeadline);
    }
}
