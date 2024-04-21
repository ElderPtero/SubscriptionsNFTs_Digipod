// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Treasury } from "../src/Treasury.sol";
import { Factory1167 } from "../src/Factory1167.sol";
import { Rewards1167 } from "../src/Rewards1167.sol";
import { Payments } from "../src/Payments.sol";
import { SubscriptionManagement } from "../src/SubscriptionManagement.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import { TestDeployDigipod } from "../script/TestDeployDigipod.s.sol";
import "forge-std/Test.sol";

//tests Deploy script which can be re used for other tests
contract TestDeployDigipodTest is Test {
    Payments public payments;
    Treasury public treasury;
    Rewards1167 public rewards1167;
    IBeacon public beaconFactory1167;
    Factory1167 public proxyFactory1167;
    Factory1167 public implementationFactory1167;
    IBeacon public beaconSubscriptionManagement;
    SubscriptionManagement public proxySubscriptionManagement;
    SubscriptionManagement public implementationSubscriptionManagement;
    address public constant OPERATOR = 0x1886ffD3cFB97D1d6a6d4c2a0967365881ae8BD2;

    function setUp() external {
        //console.log("deployer run", msg.sender);
        TestDeployDigipod deployer = new TestDeployDigipod(msg.sender);
        (
            payments,
            treasury,
            rewards1167,
            beaconFactory1167,
            proxyFactory1167,
            implementationFactory1167,
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

    function test_ProxyFactoryIsOPERATORPayments() public view {
        bool hasRole = payments.hasRole(keccak256("OPERATOR_ROLE"), address(proxyFactory1167));
        bool testExpected = true;
        assertEq(hasRole, testExpected);
    }

    function test_OperatorIsOPERATORPayments() public view {
        bool hasRole = payments.hasRole(keccak256("OPERATOR_ROLE"), OPERATOR);
        bool testExpected = true;
        assertEq(hasRole, testExpected);
    }

    // Test Treasury Deployment
    function test_OnwerTreasuryIsDeployer() public view {
        address onwerTreasury = treasury.owner(); //New VestingWallet contract merges  Onwer and Beneficiary in asingle
            // address (which we set in the constructor as
        // the beneficiary )
        assertEq(onwerTreasury, msg.sender);
    }

    function test_SubscriptionAddressIsCorrectFactory() public view {
        bool hasRole = payments.hasRole(keccak256("OPERATOR_ROLE"), OPERATOR);
        bool testExpected = true;
        assertEq(hasRole, testExpected);
    }

    // Test Treasury Deployment
    function test_NFTImplementationinNFTFactoryisRewards1167() public view {
        address nft_implementation = proxyFactory1167.contractBase(); //New VestingWallet contract merges  Onwer
        assertEq(nft_implementation, address(rewards1167));
    }

    function test_SubscriptionManagementinNFTFactoryisProxySubscriptionManagement() public view {
        address nft_implementation = proxyFactory1167.subscriptionAddress(); //New VestingWallet contract merges  Onwer
        assertEq(nft_implementation, address(proxySubscriptionManagement));
    }

    function test_AdminFactory1167IsDeployer() public view {
        bool adminFactory1167 =
            proxyFactory1167.hasRole(0x0000000000000000000000000000000000000000000000000000000000000000, msg.sender);
        assertEq(adminFactory1167, true);
    }

    function test_AdminFactory1167IsOperator() public view {
        bool adminFactory1167 =
            proxyFactory1167.hasRole(0x0000000000000000000000000000000000000000000000000000000000000000, OPERATOR);
        assertEq(adminFactory1167, true);
    }

    function test_DeployerProxyFactoryIsProxySubscriptionManagement() public view {
        bool hasRole = proxyFactory1167.hasRole(keccak256("DEPLOYER_ROLE"), address(proxySubscriptionManagement));
        bool testExpected = true;
        assertEq(hasRole, testExpected);
    }

    //Test SubscriptionManagementDeployment

    function test_AdminSubscriptionManagementIsDeployer() public view {
        bool adminSubscriptionManagement = proxySubscriptionManagement.hasRole(
            0x0000000000000000000000000000000000000000000000000000000000000000, msg.sender
        );
        assertEq(adminSubscriptionManagement, true);
    }

    function test_AdminSubscriptionManagementIsOperator() public view {
        bool adminSubscriptionManagement = proxySubscriptionManagement.hasRole(
            0x0000000000000000000000000000000000000000000000000000000000000000, OPERATOR
        );
        assertEq(adminSubscriptionManagement, true);
    }

    function test_podTreasuryisTreasuryinSubscriptionMembership() public view {
        address treasuryAddress = proxySubscriptionManagement.podTreasury();
        assertEq(treasuryAddress, address(treasury));
    }

    function test_podPaymentsisPaymentsinSubscriptionMembership() public view {
        address paymentsAddress = proxySubscriptionManagement.podPayments();
        assertEq(paymentsAddress, address(payments));
    }

    function test_podNFTfactoryisFactory1167inSubscriptionMembership() public view {
        address factoryAddress = proxySubscriptionManagement.podNFTfactory();
        assertEq(factoryAddress, address(proxyFactory1167));
    }
}
