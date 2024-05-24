// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Rewards1167 } from "../src/Rewards1167.sol";
import { Payments } from "../src/Payments.sol";
import { SubscriptionManagementV2 } from "../src/SubscriptionManagementV2.sol";
import { IBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import { TestDeployDigipodV2 } from "../script/TestDeployDigipodV2.s.sol";
import { Merkle } from "murky/src/Merkle.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "forge-std/Test.sol";

//tests Deploy script which can be re used for other tests
contract SubscriptionManagementTest is Test {
    Payments payments;
    Rewards1167 rewards1167;
    IBeacon beaconSubscriptionManagement;
    SubscriptionManagementV2 proxySubscriptionManagement;
    SubscriptionManagementV2 implementationSubscriptionManagement;
    address OPERATOR = 0x1886ffD3cFB97D1d6a6d4c2a0967365881ae8BD2;
    Merkle whitelistMerkle;
    bytes32 whitelistRoot;
    bytes32[] whitelistData = new bytes32[](2);

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
    uint16 basis_points = 10_000;
    uint32 reward0 = 0;
    uint32 reward1 = 1;
    uint32 reward2 = 2;
    uint256[] rewardNFTids0 = [maxBuyer, maxBuyer + 1, maxBuyer + 2];
    uint256[] rewardNFTids1 = [maxBuyer + 3, maxBuyer + 4, maxBuyer + 5];
    uint256[] rewardNFTids2 = [maxBuyer + 6, maxBuyer + 7, maxBuyer + 8];
    string[] rewardCIDs0 =
        ["Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"];
    string[] rewardCIDs1 = ["Qmbbbbbbbbbbbbbbbbbbbbbbbbb", "Qmbbbbbbbbbbbbbbbbbbbbbbbbb", "Qmbbbbbbbbbbbbbbbbbbbbbbbbb"];
    string[] rewardCIDs2 =
        ["Qmccccccccccccccccccccccccc", "Qmddddddddddddddddddddddddddd", "Qmeeeeeeeeeeeeeeeeeeeeeeeee"];
    string[] rewardCIDsWrong = [
        "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    ];
    uint256[] rewardNFTidsWrongLength = [4, 5];
    uint256[] rewardNFTidsWrong = [8, 7, 6];
    uint256 mintAmount1 = 1;
    uint256 mintAmount2 = 2;
    uint256 mintAmount3 = 3;
    uint16 maxMint2 = 2;
    uint16 maxMint3 = 3;
    string[] rewardCId = ["aaaaaaaaa"];
    uint8[] rewardsTest = [0, 0, 0];
    uint256[] rewardNFTidsTest = [4];

    function setUp() external {
        console.log("Deployer,", msg.sender);
        payable(collector1).transfer(10 ether);
        payable(collector2).transfer(10 ether);
        payable(creator1).transfer(10 ether);
        payable(hacker).transfer(10 ether);
        whitelistMerkle = new Merkle();
        whitelistData[0] = bytes32(keccak256(abi.encodePacked(collector1)));
        whitelistData[1] = bytes32(keccak256(abi.encodePacked(creator1)));
        whitelistRoot = whitelistMerkle.getRoot(whitelistData);
        TestDeployDigipodV2 deployer = new TestDeployDigipodV2();
        (payments, rewards1167,, proxySubscriptionManagement,) = deployer.run();
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////   HELPERS   ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    function helper_CreateProject(address creator) public returns (uint256 outputProjectId) {
        vm.prank(creator, creator);
        outputProjectId = proxySubscriptionManagement.createProject(
            name, symbol, CID, royalty, price, maxBuyer, maxMint3, backendId, rewards
        );
    }

    function helper_CreateProjectSpecificMaxMints(
        address creator,
        uint16 maxMint
    )
        public
        returns (uint256 outputProjectId)
    {
        vm.prank(creator, creator);
        outputProjectId = proxySubscriptionManagement.createProject(
            name, symbol, CID, royalty, price, maxBuyer, maxMint, backendId, rewards
        );
    }

    function helper_CreateAndSellOut(address creator) public returns (uint256 outputProjectId) {
        outputProjectId = helper_CreateProject(creator);

        uint256 amount = price + 0.069 ether;

        vm.prank(creator, creator);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);

        vm.startPrank(collector1, collector1);
        proxySubscriptionManagement.buySubscription{ value: amount * maxBuyer }(outputProjectId, maxBuyer);
        vm.stopPrank();
    }

    function helper_CreateProject_SellOut_SubmitAllRewards() public returns (uint256 outputProjectId) {
        outputProjectId = helper_CreateAndSellOut(creator1);
        vm.startPrank(creator1, creator1);
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        proxySubscriptionManagement.setValid(outputProjectId, reward1, rewardNFTids1, rewardCIDs1);
        proxySubscriptionManagement.setValid(outputProjectId, reward2, rewardNFTids2, rewardCIDs2);
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////   TESTS     ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////
    ////////////////////////   Create Project   ////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    function test_CreatesProject_createsOneProject() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        assertEq(outputProjectId, projectId0, " output ID should be 0");
        SubscriptionManagementV2.ProjectInfo memory projectInfo =
            proxySubscriptionManagement.getProject(outputProjectId);
        assertEq(projectInfo.price, price);
        assertEq(projectInfo.projectOwner, address(creator1));
        assertEq(projectInfo.maxBuyers, maxBuyer);
        assertEq(projectInfo.currentBuyers, 0);
        assertEq(projectInfo.backendId, backendId);
        assertEq(projectInfo.rewards[0], rewards[0]);
        assertEq(projectInfo.rewards[1], rewards[1]);
        assertEq(projectInfo.rewards[2], rewards[2]);
        bool hasRole =
            Rewards1167(projectInfo.nftContract).hasRole(keccak256("MINTER_ROLE"), address(proxySubscriptionManagement));
        assertEq(hasRole, true);
        bool hasRoleCreator = Rewards1167(projectInfo.nftContract).hasRole(
            0x0000000000000000000000000000000000000000000000000000000000000000, address(creator1)
        );
        assertEq(hasRoleCreator, true, "Creator Should have admin role");
        // Note on this test, we are not giving a minter role to the user. Does it make sense? It is his contract after
        // all. So .. weird.
    }

    function test_CreateProject_RevertsBuyersAre0() public {
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__InvalidNrSubscBuyers.selector)
        );
        proxySubscriptionManagement.createProject(name, symbol, CID, royalty, price, 0, maxMint2, backendId, rewards);
    }

    function test_CreateProject_RevertsInvalidName() public {
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagementV2.SubscriptionMgmt__CreateProject_InvalidNameOrSymbol.selector
            )
        );
        proxySubscriptionManagement.createProject(
            "", symbol, CID, royalty, price, maxBuyer, maxMint2, backendId, rewards
        );
    }

    function test_CreateProject_RevertsInvalidSymbol() public {
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagementV2.SubscriptionMgmt__CreateProject_InvalidNameOrSymbol.selector
            )
        );
        proxySubscriptionManagement.createProject(name, "", CID, royalty, price, maxBuyer, maxMint2, backendId, rewards);
    }

    /////////////////////////////////////////////////////////////////////////
    ////////////////////////   Buy Subscription   //////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function test_BuySubscription_SaleNotOpen() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        // Sale not Open
        vm.prank(collector1, collector1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__BuySubscription_SaleNotOpen.selector)
        );
        proxySubscriptionManagement.buySubscription(outputProjectId, mintAmount1);
    }

    function test_BuySubscription_NotEnoughEth() public {
        uint256 outputProjectId = helper_CreateProject(creator1);

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);

        vm.prank(collector1, collector1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__BuySubscription_NotEnoughEth.selector)
        );
        proxySubscriptionManagement.buySubscription(outputProjectId, mintAmount1);
    }

    event BoughtSubscription(
        address indexed buyer, uint256[] nftId, uint256 projectId, string cid, uint256 amountMinted
    );

    function test_BuySubscription_SingleSucessfulPurchase() public {
        uint256 outputProjectId = helper_CreateProject(creator1);

        uint256 balanceStartCollector1 = collector1.balance;
        uint256 balanceStartCreator1 = creator1.balance;
        uint256 balanceStartPayments = address(payments).balance;
        uint256 balanceStartSubscriptionManagement = address(proxySubscriptionManagement).balance;

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);
        uint256 amount = 1.069 ether;

        // check event emission is correct
        vm.prank(collector1, collector1);
        vm.expectEmit(address(proxySubscriptionManagement));
        uint256[] memory nftIDs = new uint256[](1);
        nftIDs[0] = 0;
        emit BoughtSubscription(collector1, nftIDs, 0, "QmX43d9EgRGaCBgxvu3FVqrFUJiijd3JcXxoXbtHHVd8rA", 1);
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId, mintAmount1);

        uint256 balanceEndCollector1 = collector1.balance;
        uint256 balanceEndCreator1 = creator1.balance;
        uint256 balanceEndPayments = address(payments).balance;
        uint256 balanceEndSubscriptionManagement = address(proxySubscriptionManagement).balance;

        //check money was transferred
        uint256 fees = (price * proxySubscriptionManagement.platform_fee()) / basis_points;
        uint256 owner_adv = (price * proxySubscriptionManagement.advance_creator()) / basis_points;
        uint256 owner_rev = price - fees - owner_adv;
        assertEq(balanceEndCollector1, balanceStartCollector1 - amount, "collector should have spent amount ");
        assertEq(balanceEndCreator1, balanceStartCreator1 + owner_adv, "creator should get some upfront money");
        assertEq(
            balanceEndPayments, balanceStartPayments + owner_rev, "payments should got price minus fees and advance"
        );
        assertEq(
            balanceEndSubscriptionManagement,
            balanceStartSubscriptionManagement + (amount - owner_rev - owner_adv),
            " SubscriptionManagementV2 should have 0.069 ETH"
        );

        //check NFT was created
        SubscriptionManagementV2.ProjectInfo memory projectInfo =
            proxySubscriptionManagement.getProject(outputProjectId);
        Rewards1167 token = Rewards1167(projectInfo.nftContract);
        uint256 nftId = 0;
        assertEq(token.ownerOf(nftId), collector1);
    }

    function test_BuySubscription_SellOutSinglePurchases() public {
        uint256 outputProjectId = helper_CreateProject(creator1);

        uint256 amount = 1.069 ether;

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);

        vm.startPrank(collector1, collector1);
        for (uint16 i = 0; i < maxBuyer - 1; i++) {
            proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId, mintAmount1);
        }
        vm.stopPrank();

        vm.prank(collector2, collector2);
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId, mintAmount1);

        SubscriptionManagementV2.ProjectInfo memory projectInfo =
            proxySubscriptionManagement.getProject(outputProjectId);
        Rewards1167 token = Rewards1167(projectInfo.nftContract);
        assertEq(token.ownerOf(0), collector1);
        assertEq(token.ownerOf(1), collector1);
        assertEq(token.ownerOf(2), collector2);

        vm.prank(collector2);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__BuySubscription_SoldOut.selector)
        );
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId, mintAmount1);
    }

    function test_BuySubscriptionMultiple_Sucess() public {
        uint256 outputProjectId = helper_CreateProject(creator1);

        uint256 balanceStartCollector1 = collector1.balance;
        uint256 balanceStartCreator1 = creator1.balance;
        uint256 balanceStartPayments = address(payments).balance;
        uint256 balanceStartSubscriptionManagement = address(proxySubscriptionManagement).balance;

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);
        uint256 amount = 1.069 ether;

        // check event emission is correct
        vm.prank(collector1, collector1);
        vm.expectEmit(address(proxySubscriptionManagement));
        uint256[] memory nftIDs = new uint256[](2);
        nftIDs[0] = 0;
        nftIDs[1] = 1;
        emit BoughtSubscription(collector1, nftIDs, 0, "QmX43d9EgRGaCBgxvu3FVqrFUJiijd3JcXxoXbtHHVd8rA", 2);
        proxySubscriptionManagement.buySubscription{ value: amount * mintAmount2 }(outputProjectId, mintAmount2);

        uint256 balanceEndCollector1 = collector1.balance;
        uint256 balanceEndCreator1 = creator1.balance;
        uint256 balanceEndPayments = address(payments).balance;
        uint256 balanceEndSubscriptionManagement = address(proxySubscriptionManagement).balance;

        //check money was transferred
        uint256 fees = (price * proxySubscriptionManagement.platform_fee()) / basis_points;
        uint256 owner_adv = (price * proxySubscriptionManagement.advance_creator()) / basis_points;
        uint256 owner_rev = price - fees - owner_adv;
        assertEq(
            balanceEndCollector1, balanceStartCollector1 - (amount * mintAmount2), "collector should have spent amount "
        );
        assertEq(
            balanceEndCreator1,
            balanceStartCreator1 + (owner_adv * mintAmount2),
            "creator should get some upfront money"
        );
        assertEq(
            balanceEndPayments,
            balanceStartPayments + (owner_rev * mintAmount2),
            "payments should got price minus fees and advance"
        );
        assertEq(
            balanceEndSubscriptionManagement,
            balanceStartSubscriptionManagement + (amount - owner_rev - owner_adv) * mintAmount2,
            " SubscriptionManagementV2 should have 0.069 ETH"
        );

        //check NFT was created
        SubscriptionManagementV2.ProjectInfo memory projectInfo =
            proxySubscriptionManagement.getProject(outputProjectId);
        Rewards1167 token = Rewards1167(projectInfo.nftContract);

        assertEq(token.ownerOf(nftIDs[0]), collector1);
        assertEq(token.ownerOf(nftIDs[1]), collector1);
    }

    function test_BuySubscriptionMultiple_CannotMint_TryingToMintAboveSupply() public {
        uint256 outputProjectId = helper_CreateProjectSpecificMaxMints(creator1, maxMint2);
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);
        uint256 amount = 1.069 ether;

        // check event emission is correct
        vm.prank(collector1, collector1);
        proxySubscriptionManagement.buySubscription{ value: amount * mintAmount2 }(outputProjectId, mintAmount2);
        vm.prank(collector2);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagementV2.SubscriptionMgmt__BuySubscription_NotEnoughNFTsForSale.selector
            )
        );
        proxySubscriptionManagement.buySubscription{ value: amount * mintAmount2 }(outputProjectId, mintAmount2);
    }

    /////////////////////////////////////////////////////////////////////////
    ////////////////////////////   WhiteList   /////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function test_SetWhiteListStatus_NotOnwer() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__NotProjectOnwer.selector));
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 1);
    }

    function test_SetWhiteListStatus_InvalidStatus() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__setWhitelistStatus_InvalidStatus.selector)
        );
        uint256 invalidStatus = 3; // valid status: 0 -> closed, 1 -> whiteList, 2-> Public sale
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, invalidStatus);
    }

    function test_SetWhiteListStatus_SetsStatusCorrectly() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);
        assertEq(proxySubscriptionManagement.whitelistStatus(outputProjectId), 2);

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 1);
        assertEq(proxySubscriptionManagement.whitelistStatus(outputProjectId), 1);

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 0);
        assertEq(proxySubscriptionManagement.whitelistStatus(outputProjectId), 0);
    }

    function test_allowlistMint_Sucess() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        vm.startPrank(creator1, creator1);
        proxySubscriptionManagement.setWhitelist(outputProjectId, whitelistRoot);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 1);
        vm.stopPrank();

        bytes32[] memory proof = whitelistMerkle.getProof(whitelistData, 0);
        uint256 amount = price + 0.069 ether;
        vm.prank(collector1);
        vm.expectEmit(address(proxySubscriptionManagement));
        uint256[] memory nftIDs = new uint256[](1);
        nftIDs[0] = 0;
        emit BoughtSubscription(collector1, nftIDs, 0, "QmX43d9EgRGaCBgxvu3FVqrFUJiijd3JcXxoXbtHHVd8rA", 1);
        proxySubscriptionManagement.buySubscriptionWhitelist{ value: amount }(outputProjectId, proof, mintAmount1);
    }

    function test_allowlistMint_InvalidProof() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        vm.startPrank(creator1, creator1);
        proxySubscriptionManagement.setWhitelist(outputProjectId, whitelistRoot);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 1);
        vm.stopPrank();

        // use a real proof from a different address
        bytes32[] memory proof = whitelistMerkle.getProof(whitelistData, 0);
        uint256 amount = price + 0.069 ether;
        vm.prank(hacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagementV2.SubscriptionMgmt__BuySubscriptionWhitelist_InvalidProof.selector
            )
        );
        proxySubscriptionManagement.buySubscriptionWhitelist{ value: amount }(outputProjectId, proof, mintAmount1);
    }

    function test_allowlistMint_TryingMintAboveCap() public {
        uint256 outputProjectId = helper_CreateProjectSpecificMaxMints(creator1, maxMint2);
        vm.startPrank(creator1, creator1);
        proxySubscriptionManagement.setWhitelist(outputProjectId, whitelistRoot);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 1);
        vm.stopPrank();

        // use a real proof from a different address
        bytes32[] memory proof = whitelistMerkle.getProof(whitelistData, 0);
        uint256 amount = price + 0.069 ether;
        vm.startPrank(collector1);
        // test both we cannot mint above cap but also if user splits the minting in multiple transactions
        proxySubscriptionManagement.buySubscriptionWhitelist{ value: amount }(outputProjectId, proof, mintAmount1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagementV2.SubscriptionMgmt__BuySubscription_CurrentMintAboveMaxMintAllowed.selector
            )
        );
        proxySubscriptionManagement.buySubscriptionWhitelist{ value: amount * mintAmount2 }(
            outputProjectId, proof, mintAmount2
        );
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////////////
    //////////////////////////   BlockContract   ///////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function test_BlockContract_NotOnwer() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__NotProjectOnwer.selector));
        proxySubscriptionManagement.blockContract(outputProjectId);
    }

    function test_BlockContract_Sucessfull() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        vm.startPrank(creator1, creator1);
        proxySubscriptionManagement.blockContract(outputProjectId);
        assertEq(proxySubscriptionManagement.isBlocked(outputProjectId), true);
        vm.stopPrank();
    }

    function test_BuySubscription_BlockedContract() public {
        uint256 outputProjectId = helper_CreateProject(creator1);

        uint256 amount = 1.069 ether;
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);

        vm.prank(collector1, collector1);
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId, mintAmount1);

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.blockContract(outputProjectId);

        vm.prank(collector2, collector2);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagementV2.SubscriptionMgmt__BuySubscription_ProjectBlockedFactory.selector
            )
        );
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId, mintAmount1);

        // NOTE TO SELF: we should remove one of the transfers here and just combine Treasury with Subscription
        // Management. Add releaseEth method.
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////   SetValid   ///////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function test_setValid_NotOnwer() public {
        uint256 outputProjectId = helper_CreateProject(creator1);
        vm.prank(hacker, hacker);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__NotProjectOnwer.selector));
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
    }

    function test_setValid_ProjectNotClosedOrSellOut() public {
        uint256 outputProjectId = helper_CreateProject(creator1);

        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__setValid_ProjectNotClosed.selector)
        );
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
    }

    function test_setValid_invalidRewards() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        uint32 rewardIdwrong = uint32(rewards.length) + 1;
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__setValid_InvalidRewardId.selector)
        );
        proxySubscriptionManagement.setValid(outputProjectId, rewardIdwrong, rewardNFTids0, rewardCIDs0);
    }

    function test_setValid_invalidIdsLength() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagementV2.SubscriptionMgmt__setValid_nftIdsNotMatchSubscriptionNr.selector
            )
        );
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTidsWrongLength, rewardCIDs0);
    }

    function test_setValid_invalidCIDsLength() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__setValid_InvalidCIDsLength.selector)
        );
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDsWrong);
    }

    function test_setValid_InvalidNftIds() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__setValid_InvalidNFTIDs.selector)
        );
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTidsWrong, rewardCIDs0);
    }

    function test_setValid_Sucessful() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        assertEq(proxySubscriptionManagement.rewardSubmitted(outputProjectId, reward0), true);
        assertEq(proxySubscriptionManagement.rewardSubmitted(outputProjectId, reward2), false);
        assertEq(
            proxySubscriptionManagement.indexToCID(outputProjectId, rewardNFTids0[0]),
            "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );
        assertEq(
            proxySubscriptionManagement.indexToCID(outputProjectId, rewardNFTids0[1]),
            "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );
        assertEq(
            proxySubscriptionManagement.indexToCID(outputProjectId, rewardNFTids0[2]),
            "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );

        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__setValid_RewardAlreadyValidated.selector)
        );
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
    }

    function test_SetValid_Sucessful_Payment2Rewards() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        vm.startPrank(creator1, creator1);
        uint256 amount = 0.85 ether;
        uint256 balanceStartCreator1 = creator1.balance;
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        proxySubscriptionManagement.setValid(outputProjectId, reward1, rewardNFTids1, rewardCIDs1);
        uint256 balanceEndCreator1 = creator1.balance;
        assertEq(balanceEndCreator1, balanceStartCreator1 + amount * 2);
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////   mintReward   ///////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function test_mintRewardNFT_RewardNotSubmitted() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        vm.prank(collector1, collector1);
        uint256 subscriptionNFTid = 3;
        uint32 wrongRewardid = 1;
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__MintReward_RewardNotSubmitted.selector)
        );
        proxySubscriptionManagement.mintRewardNFT(outputProjectId, wrongRewardid, subscriptionNFTid);
    }

    function test_mintRewardNFT_SubscriptionNFTinvalid() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        vm.prank(collector1, collector2);
        uint256 wrongSubscriptionNFTid = maxBuyer;
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagementV2.SubscriptionMgmt__MintReward_SubscriptionNFTNotValid.selector
            )
        );
        proxySubscriptionManagement.mintRewardNFT(outputProjectId, reward0, wrongSubscriptionNFTid);
    }

    function test_mintRewardNFT_NonSubscriptor() public {
        uint256 outputProjectId = helper_CreateAndSellOut(creator1);
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        vm.prank(hacker, hacker);
        uint256 subscriptionNFTid = 0;
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__MintReward_NonSubscriptor.selector)
        );
        proxySubscriptionManagement.mintRewardNFT(outputProjectId, reward0, subscriptionNFTid);
    }

    event ERC721Minted(address owner, uint256 nftId, uint256 nftSubscriptionId, address tokenContract, uint256 amount);

    function test_mintRewardNFT_Successful() public {
        uint256 outputProjectId = helper_CreateProject_SellOut_SubmitAllRewards();
        vm.startPrank(collector1, collector1);
        uint256 subscriptionNFTid = 0;
        uint256 tokenId = 3;
        vm.expectEmit(address(proxySubscriptionManagement));
        emit ERC721Minted(
            collector1, tokenId, subscriptionNFTid, address(proxySubscriptionManagement.contracts(outputProjectId)), 1
        );
        proxySubscriptionManagement.mintRewardNFT(outputProjectId, reward0, subscriptionNFTid);

        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagementV2.SubscriptionMgmt__MintReward_AlreadyMinted.selector)
        );
        proxySubscriptionManagement.mintRewardNFT(outputProjectId, reward0, subscriptionNFTid);
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////   withdraw   ///////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function test_withdraw_notAdmin() public {
        helper_CreateProject_SellOut_SubmitAllRewards();
        vm.prank(hacker);
        vm.expectRevert();
        proxySubscriptionManagement.withdraw();
    }

    function test_withdraw_Sucess() public {
        helper_CreateProject_SellOut_SubmitAllRewards();

        address deployerContracts = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        uint256 balanceStartCreator1 = deployerContracts.balance;
        uint256 balanceStartProxySubscription = address(proxySubscriptionManagement).balance;
        vm.prank(deployerContracts);
        proxySubscriptionManagement.withdraw();

        uint256 balanceEndCreator1 = deployerContracts.balance;
        uint256 balanceEndProxySubscription = address(proxySubscriptionManagement).balance;
        assertEq(balanceEndCreator1, balanceStartCreator1 + balanceStartProxySubscription);
        assertEq(balanceEndProxySubscription, 0);
    }

    function test_live() public {
        vm.startPrank(creator1, creator1);
        uint256 outputProjectId = proxySubscriptionManagement.createProject(
            "Antartica", "Antartica1", CID, royalty, price, 4, 1, backendId, rewardsTest
        );
        uint256 amount = price;
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);
        proxySubscriptionManagement.buySubscription{ value: amount * 2 }(outputProjectId, 2);
        proxySubscriptionManagement.blockContract(outputProjectId);
        proxySubscriptionManagement.setValid(outputProjectId, reward0, rewardNFTidsTest, rewardCId);
        vm.stopPrank();
    }
}
