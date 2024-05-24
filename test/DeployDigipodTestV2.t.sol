// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Rewards1167 } from "../src/Rewards1167.sol";
import { Payments } from "../src/Payments.sol";
import { SubscriptionManagementV2 } from "../src/SubscriptionManagementV2.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import { TestDeployDigipodV2 } from "../script/TestDeployDigipodV2.s.sol";
import "forge-std/Test.sol";

//tests Deploy script which can be re used for other tests
contract TestDeployDigipodTest is Test {
    Payments public payments;
    Rewards1167 public rewards1167;
    IBeacon public beaconSubscriptionManagement;
    SubscriptionManagementV2 public proxySubscriptionManagement;
    SubscriptionManagementV2 public implementationSubscriptionManagement;

    function setUp() external {
        //console.log("deployer run", msg.sender);
        TestDeployDigipodV2 deployer = new TestDeployDigipodV2();
        (
            payments,
            rewards1167,
            beaconSubscriptionManagement,
            proxySubscriptionManagement,
            implementationSubscriptionManagement
        ) = deployer.run();
    }

    // TEST Payments deployment
    function test_AdminPaymentsIsDeployer() public view {
        bool adminPayments =
            payments.hasRole(0x0000000000000000000000000000000000000000000000000000000000000000, msg.sender);
        assertEq(adminPayments, true);
    }

    function test_SubscriptionManagmtIsOPERATORPayments() public view {
        bool hasRole = payments.hasRole(keccak256("OPERATOR_ROLE"), address(proxySubscriptionManagement));
        assertEq(hasRole, true);
    }

    // Test Treasury Deployment
    function test_contractbaseisRewards1167() public view {
        address nft_implementation = proxySubscriptionManagement.contractBase(); //New VestingWallet contract merges  Onwer
        assertEq(nft_implementation, address(rewards1167));
    }

    //Test SubscriptionManagementDeployment

    function test_AdminSubscriptionManagementIsDeployer() public view {
        bool adminSubscriptionManagement = proxySubscriptionManagement.hasRole(
            0x0000000000000000000000000000000000000000000000000000000000000000, msg.sender
        );
        assertEq(adminSubscriptionManagement, true);
    }

    function test_podPaymentsisPaymentsinSubscriptionMembership() public view {
        address paymentsAddress = proxySubscriptionManagement.podPayments();
        assertEq(paymentsAddress, address(payments));
    }
}
