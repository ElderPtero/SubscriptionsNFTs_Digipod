//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

error Payments__InsufficientBalance();
error Payments__FailedWithdraw();

contract Payments is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable { }

    // Fallback function is called when msg.data is not empty
    fallback() external payable { }

    function withdraw(address payable beneficiary, uint256 amount) public onlyRole(OPERATOR_ROLE) {
        if (amount > address(this).balance) revert Payments__InsufficientBalance();
        (bool success,) = payable(beneficiary).call{ value: amount }("");
        if (!success) revert Payments__FailedWithdraw();
    }
}
