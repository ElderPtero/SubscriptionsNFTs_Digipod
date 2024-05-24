// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { Rewards1167 } from "../src/Rewards1167.sol";
import { Payments } from "../src/Payments.sol";
import { SubscriptionManagementV2 } from "../src/SubscriptionManagementV2.sol";
import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting

contract TestDeployDigipodV2 is Script {
    uint16 royalties = 500;
    address initialOnwerAddress;
    //this constructor ensures we deploy to the right address

    constructor() {
        initialOnwerAddress = address(0x6845fbB359fE31A929aDe0b108744720F5Ee00B5);
    }

    function run()
        external
        returns (
            Payments payments,
            Rewards1167 rewards1167,
            IBeacon beaconSubscriptionManagement,
            SubscriptionManagementV2 proxySubscriptionManagement,
            SubscriptionManagementV2 implementationSubscriptionManagement
        )
    {
        vm.startBroadcast();
        console.log("deployer inside for all ", initialOnwerAddress);
        payments = new Payments();
        console.log("Deployed Payments");
        rewards1167 =
            new Rewards1167(payable(address(initialOnwerAddress)), royalties, "Digipod", "POD", initialOnwerAddress);
        console.log("Deployed Rewards");
        beaconSubscriptionManagement =
            IBeacon(Upgrades.deployBeacon("SubscriptionManagementV2.sol", initialOnwerAddress));
        proxySubscriptionManagement = SubscriptionManagementV2(
            Upgrades.deployBeaconProxy(
                address(beaconSubscriptionManagement),
                abi.encodeCall(SubscriptionManagementV2.initialize, (address(payments), address(rewards1167)))
            )
        );
        console.log("Deployed SubscriptionManagement");
        implementationSubscriptionManagement =
            SubscriptionManagementV2(IBeacon(beaconSubscriptionManagement).implementation());

        //Roles
        payments.grantRole(keccak256("OPERATOR_ROLE"), address(proxySubscriptionManagement));
        //// 0x0000000000000000000000000000000000000000000000000000000000000000 is Default ADMIN Role in OpenZeppeling
        // Contracts
        vm.stopBroadcast();
    }
}
