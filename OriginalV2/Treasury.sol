//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";  // VestingWallet already is Onwable

contract Treasury is VestingWallet {
    //Onwer is the beneficiary now
    constructor(address beneficiaryAddress) VestingWallet(beneficiaryAddress, uint64(block.timestamp), 0) { }

    function releasableEth() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    function releasableToken(address token) public view returns (uint256) {
        return vestedAmount(token, uint64(block.timestamp)) - released(token);
    }

    function releaseEth() public onlyOwner {
        release();
    }

    function releaseToken(address token) public onlyOwner {
        release(token);
    }
}
