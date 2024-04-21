// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { Factory1167 } from "../src/Factory1167.sol";
import { Rewards1167 } from "../src/Rewards1167.sol";
import { Payments } from "../src/Payments.sol";
import { SubscriptionManagement } from "../src/SubscriptionManagement.sol";
import { Treasury } from "../src/Treasury.sol";
import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting

contract TestDeployDigipod is Script {
    uint16 royalties = 500;
    address operator = 0x1886ffD3cFB97D1d6a6d4c2a0967365881ae8BD2;
    address initialOnwerAddress;

    //this constructor ensures we deploy to the right address
    constructor(address deployAddress) {
        initialOnwerAddress = deployAddress;
    }

    function run()
        external
        returns (
            Payments payments,
            Treasury treasury,
            Rewards1167 rewards1167,
            IBeacon beaconFactory1167,
            Factory1167 proxyFactory1167,
            Factory1167 implementationFactory1167,
            IBeacon beaconSubscriptionManagement,
            SubscriptionManagement proxySubscriptionManagement,
            SubscriptionManagement implementationSubscriptionManagement
        )
    {
        vm.startBroadcast();
        //console.log("deployer inside for all ", initialOnwerAddress);
        payments = new Payments();
        treasury = new Treasury(initialOnwerAddress);
        rewards1167 = new Rewards1167(payable(address(treasury)), royalties, "Digipod", "POD", initialOnwerAddress);

        beaconFactory1167 = IBeacon(Upgrades.deployBeacon("Factory1167.sol", initialOnwerAddress));
        proxyFactory1167 = Factory1167(
            Upgrades.deployBeaconProxy(
                address(beaconFactory1167), abi.encodeCall(Factory1167.initialize, address(rewards1167))
            )
        );
        implementationFactory1167 = Factory1167(beaconFactory1167.implementation());

        beaconSubscriptionManagement = IBeacon(Upgrades.deployBeacon("SubscriptionManagement.sol", initialOnwerAddress));
        proxySubscriptionManagement = SubscriptionManagement(
            Upgrades.deployBeaconProxy(
                address(beaconSubscriptionManagement),
                abi.encodeCall(
                    SubscriptionManagement.initialize, (address(treasury), address(payments), address(proxyFactory1167))
                )
            )
        );
        implementationSubscriptionManagement =
            SubscriptionManagement(IBeacon(beaconSubscriptionManagement).implementation());

        //Roles

        proxyFactory1167.setSubscriptionAddress(address(proxySubscriptionManagement));
        proxyFactory1167.setPaymentsAddress(payable(address(payments)));
        proxyFactory1167.grantRole(keccak256("DEPLOYER_ROLE"), address(proxySubscriptionManagement));
        //payments.grantRole(keccak256("OPERATOR_ROLE"), address(proxySubscriptionManagement));
        payments.grantRole(keccak256("OPERATOR_ROLE"), address(proxyFactory1167));
        //// 0x0000000000000000000000000000000000000000000000000000000000000000 is Default ADMIN Role in OpenZeppeling
        // Contracts
        proxySubscriptionManagement.grantRole(
            0x0000000000000000000000000000000000000000000000000000000000000000, operator
        );
        proxyFactory1167.grantRole(0x0000000000000000000000000000000000000000000000000000000000000000, operator);
        payments.grantRole(keccak256("OPERATOR_ROLE"), operator);
        vm.stopBroadcast();
    }
}
