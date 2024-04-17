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
contract SubscriptionManagementTest is Test {
    Payments payments;
    Treasury treasury;
    Rewards1167 rewards1167;
    IBeacon beaconFactory1167;
    Factory1167 proxyFactory1167;
    Factory1167 implementationFactory1167;
    IBeacon beaconSubscriptionManagement;
    SubscriptionManagement proxySubscriptionManagement;
    SubscriptionManagement implementationSubscriptionManagement;
    address OPERATOR = 0x1886ffD3cFB97D1d6a6d4c2a0967365881ae8BD2;

    function setUp() external {
        console.log("deployer run", msg.sender);
        TestDeployDigipod deployer = new TestDeployDigipod(msg.sender);
        (payments, treasury, rewards1167,, proxyFactory1167,,, proxySubscriptionManagement,) = deployer.run();
    }

    // set up actors
    address creator1 = vm.addr(2);
    address creator2 = vm.addr(3);
    address collector1 = vm.addr(4);
    address collector2 = vm.addr(5);
    address hacker = vm.addr(6);
    //set up project details
    string name = "TEST CONTRACT";
    string symbol = "TEST";
    string CID = "QmX43d9EgRGaCBgxvu3FVqrFUJiijd3JcXxoXbtHHVd8rA";
    uint16 royalty = 500;
    uint256 price = 1 ether;
    uint16 maxBuyer = 3;
    string backendId = "SomeId";
    uint8[] rewards = [0, 0, 1];
    uint256 projectId0 = 0;
    uint256 projectId1 = 1;

    // Test CreateSubscription
    //1 -

    function test_CreatesProject_createsOneProject() public {
        console.log(msg.sender);
        vm.prank(creator1);
        uint256 outputProjectId =
            proxySubscriptionManagement.createProject(name, symbol, CID, royalty, price, maxBuyer, backendId, rewards);
        assertEq(outputProjectId, projectId0, " output ID should be 0");
        SubscriptionManagement.ProjectInfo memory projectInfo = proxySubscriptionManagement.getProject(outputProjectId);
        assertEq(projectInfo.price, price);
        assertEq(projectInfo.projectOwner, address(creator1));
        assertEq(projectInfo.maxBuyers, maxBuyer);
        assertEq(projectInfo.currentBuyers, 0);
        assertEq(projectInfo.backendId, backendId);
        assertEq(projectInfo.rewards[0], rewards[0]);
        assertEq(projectInfo.rewards[1], rewards[1]);
        assertEq(projectInfo.rewards[2], rewards[2]);
        bool hasRole = Rewards1167(projectInfo.nftContract).hasRole(keccak256("MINTER_ROLE"), address(proxyFactory1167));
        assertEq(hasRole, true);
        bool hasRoleCreator = Rewards1167(projectInfo.nftContract).hasRole(
            0x0000000000000000000000000000000000000000000000000000000000000000, address(creator1)
        );
        assertEq(hasRoleCreator, true, "Creator Should have admin role");
        // Note on this test, we are not giving a minter role to the user. Does it make sense? It is his contract after
        // all. So .. weird.
    }

    error SubscriptionMgmt__InvalidNrSubscBuyers();
    error SubscriptionMgmt__CreateProject_InvalidNameOrSymbol();

    function test_CreateProject_RevertsBuyersAre0() public {
        console.log(msg.sender);
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionMgmt__InvalidNrSubscBuyers.selector));
        proxySubscriptionManagement.createProject(name, symbol, CID, royalty, price, 0, backendId, rewards);
    }

    function test_CreateProject_RevertsInvalidName() public {
        console.log(msg.sender);
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionMgmt__CreateProject_InvalidNameOrSymbol.selector));
        proxySubscriptionManagement.createProject("", symbol, CID, royalty, price, maxBuyer, backendId, rewards);
    }

    function test_CreateProject_RevertsInvalidSymbol() public {
        console.log(msg.sender);
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionMgmt__CreateProject_InvalidNameOrSymbol.selector));
        proxySubscriptionManagement.createProject(name, "", CID, royalty, price, maxBuyer, backendId, rewards);
    }
}
