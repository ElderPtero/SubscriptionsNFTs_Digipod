// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Treasury } from "../src/Treasury.sol";
import { Factory1167 } from "../src/Factory1167.sol";
import { Rewards1167 } from "../src/Rewards1167.sol";
import { Payments } from "../src/Payments.sol";
import { SubscriptionManagement } from "../src/SubscriptionManagement.sol";
import { Factory1167 } from "../src/Factory1167.sol";
import { IBeacon } from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import { TestDeployDigipod } from "../script/TestDeployDigipod.s.sol";
import { Merkle } from "murky/src/Merkle.sol";
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

    function setUp() external {
        payable(collector1).transfer(10 ether);
        payable(collector2).transfer(10 ether);
        whitelistMerkle = new Merkle();
        whitelistData[0] = bytes32(keccak256(abi.encodePacked(collector1)));
        whitelistData[1] = bytes32(keccak256(abi.encodePacked(creator1)));
        whitelistRoot = whitelistMerkle.getRoot(whitelistData);
        TestDeployDigipod deployer = new TestDeployDigipod(msg.sender);
        (payments, treasury, rewards1167,, proxyFactory1167,,, proxySubscriptionManagement,) = deployer.run();
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////   HELPERS   ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    function helper_CreateProject() public returns (uint256 outputProjectId) {
        vm.prank(creator1, creator1);
        outputProjectId =
            proxySubscriptionManagement.createProject(name, symbol, CID, royalty, price, maxBuyer, backendId, rewards);
    }

    function helper_CreateAndSellOut() public returns (uint256 outputProjectId) {
        outputProjectId = helper_CreateProject();

        uint256 amount = price + 0.069 ether;

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);

        vm.startPrank(collector1, collector1);
        for (uint16 i = 0; i < maxBuyer; i++) {
            proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId);
        }
        vm.stopPrank();
    }

    function helper_CreateProject_SellOut_SubmitAllRewards() public returns (uint256 outputProjectId) {
        outputProjectId = helper_CreateAndSellOut();
        vm.startPrank(creator1, creator1);
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        proxyFactory1167.setValid(outputProjectId, reward1, rewardNFTids1, rewardCIDs1);
        proxyFactory1167.setValid(outputProjectId, reward2, rewardNFTids2, rewardCIDs2);
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////   TESTS     ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    function test_CreatesProject_createsOneProject() public {
        console.log(msg.sender);
        uint256 outputProjectId = helper_CreateProject();
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

    function test_CreateProject_RevertsBuyersAre0() public {
        console.log(msg.sender);
        vm.prank(creator1, creator1);
        vm.expectRevert(abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__InvalidNrSubscBuyers.selector));
        proxySubscriptionManagement.createProject(name, symbol, CID, royalty, price, 0, backendId, rewards);
    }

    function test_CreateProject_RevertsInvalidName() public {
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__CreateProject_InvalidNameOrSymbol.selector)
        );
        proxySubscriptionManagement.createProject("", symbol, CID, royalty, price, maxBuyer, backendId, rewards);
    }

    function test_CreateProject_RevertsInvalidSymbol() public {
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__CreateProject_InvalidNameOrSymbol.selector)
        );
        proxySubscriptionManagement.createProject(name, "", CID, royalty, price, maxBuyer, backendId, rewards);
    }

    function test_SetWhiteListStatus_NotOnwer() public {
        uint256 outputProjectId = helper_CreateProject();
        vm.prank(hacker);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__setWhitelistStatus_NotOnwer.selector)
        );
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 1);
    }

    function test_SetWhiteListStatus_InvalidStatus() public {
        uint256 outputProjectId = helper_CreateProject();
        vm.prank(creator1, creator1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__setWhitelistStatus_InvalidStatus.selector)
        );
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 3);
    }

    function test_SetWhiteListStatus_SetsStatusCorrectly() public {
        uint256 outputProjectId = helper_CreateProject();
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);
        assertEq(proxySubscriptionManagement.whitelistStatus(outputProjectId), 2);

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 1);
        assertEq(proxySubscriptionManagement.whitelistStatus(outputProjectId), 1);
    }

    // whitelistStatus

    function test_BuySubscription_SaleNotOpen() public {
        uint256 outputProjectId = helper_CreateProject();
        // Sale not Open
        vm.prank(collector1, collector1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__BuySubscription_SaleNotOpen.selector)
        );
        proxySubscriptionManagement.buySubscription(outputProjectId);
    }

    function test_BuySubscription_NotEnoughEth() public {
        uint256 outputProjectId = helper_CreateProject();

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);

        vm.prank(collector1, collector1);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__BuySubscription_NotEnoughEth.selector)
        );
        proxySubscriptionManagement.buySubscription(outputProjectId);
    }

    event BoughtSubscription(address indexed buyer, uint256 nftId, uint256 projectId, string cid);

    function test_BuySubscription_SucessfulPurchase() public {
        uint256 outputProjectId = helper_CreateProject();

        uint256 balanceStartCollector1 = collector1.balance;
        uint256 balanceStartCreator1 = creator1.balance;
        uint256 balanceStartPayments = address(payments).balance;
        uint256 balanceStartTreasury = address(treasury).balance;
        uint256 balanceStartSubscriptionManagement = address(proxySubscriptionManagement).balance;

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);
        uint256 amount = 1.069 ether;

        // check event emission is correct
        vm.prank(collector1, collector1);
        vm.expectEmit(address(proxySubscriptionManagement));
        emit BoughtSubscription(collector1, 0, 0, "QmX43d9EgRGaCBgxvu3FVqrFUJiijd3JcXxoXbtHHVd8rA");
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId);

        uint256 balanceEndCollector1 = collector1.balance;
        uint256 balanceEndCreator1 = creator1.balance;
        uint256 balanceEndPayments = address(payments).balance;
        uint256 balanceEndTreasury = address(treasury).balance;
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
        assertEq(balanceEndTreasury, balanceStartTreasury + fees, " digipod treasury should have gotten fees");
        assertEq(
            balanceEndSubscriptionManagement,
            balanceStartSubscriptionManagement + (amount - price),
            " SubscriptionManagement should have 0.069 ETH"
        );

        //check NFT was created
        SubscriptionManagement.ProjectInfo memory projectInfo = proxySubscriptionManagement.getProject(outputProjectId);
        Rewards1167 token = Rewards1167(projectInfo.nftContract);
        uint256 nftId = 0;
        console.log("default address", msg.sender);
        assertEq(token.ownerOf(nftId), collector1);

        // NOTE TO SELF: we should remove one of the transfers here and just combine Treasury with Subscription
        // Management. Add releaseEth method.
    }

    function test_BuySubscription_SellOut() public {
        uint256 outputProjectId = helper_CreateProject();

        uint256 amount = 1.069 ether;

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);

        vm.startPrank(collector1, collector1);
        for (uint16 i = 0; i < maxBuyer - 1; i++) {
            proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId);
        }
        vm.stopPrank();

        vm.prank(collector2, collector2);
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId);

        SubscriptionManagement.ProjectInfo memory projectInfo = proxySubscriptionManagement.getProject(outputProjectId);
        Rewards1167 token = Rewards1167(projectInfo.nftContract);
        assertEq(token.ownerOf(0), collector1);
        assertEq(token.ownerOf(1), collector1);
        assertEq(token.ownerOf(2), collector2);

        vm.prank(collector2);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__BuySubscription_SoldOut.selector)
        );
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId);

        // NOTE TO SELF: we should remove one of the transfers here and just combine Treasury with Subscription
        // Management. Add releaseEth method.
    }

    function test_BlockContract_NotOnwer() public {
        uint256 outputProjectId = helper_CreateProject();
        vm.prank(hacker);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__BlockContract_NotOnwer.selector)
        );
        proxySubscriptionManagement.blockContract(outputProjectId);
    }

    function test_BlockContract_Sucessfull() public {
        uint256 outputProjectId = helper_CreateProject();
        vm.startPrank(creator1, creator1);
        proxySubscriptionManagement.blockContract(outputProjectId);
        assertEq(proxyFactory1167.isBlocked(outputProjectId), true);
        vm.stopPrank();
    }

    function test_BuySubscription_BlockedContract() public {
        uint256 outputProjectId = helper_CreateProject();

        uint256 amount = 1.069 ether;
        vm.prank(creator1, creator1);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 2);

        vm.prank(collector1, collector1);
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId);

        vm.prank(creator1, creator1);
        proxySubscriptionManagement.blockContract(outputProjectId);

        vm.prank(collector2, collector2);
        vm.expectRevert(
            abi.encodeWithSelector(
                SubscriptionManagement.SubscriptionMgmt__BuySubscription_ProjectBlockedFactory.selector
            )
        );
        proxySubscriptionManagement.buySubscription{ value: amount }(outputProjectId);

        // NOTE TO SELF: we should remove one of the transfers here and just combine Treasury with Subscription
        // Management. Add releaseEth method.
    }

    function test_setValid_NotOnwer() public {
        uint256 outputProjectId = helper_CreateProject();
        vm.prank(hacker, hacker);
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__setValid_NotOnwer.selector));
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
    }

    function test_setValid_ProjectNotClosedOrSellOut() public {
        uint256 outputProjectId = helper_CreateProject();

        vm.prank(creator1, creator1);
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__setValid_ProjectNotClosed.selector));
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
    }

    function test_setValid_invalidRewards() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        uint32 rewardIdwrong = uint32(rewards.length) + 1;
        vm.prank(creator1, creator1);
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__setValid_InvalidRewardId.selector));
        proxyFactory1167.setValid(outputProjectId, rewardIdwrong, rewardNFTids0, rewardCIDs0);
    }

    function test_setValid_invalidIdsLength() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        vm.prank(creator1, creator1);
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__setValid_nftIdsNotMatchSubscriptionNr.selector));
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTidsWrongLength, rewardCIDs0);
    }

    function test_setValid_invalidCIDsLength() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        vm.prank(creator1, creator1);
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__setValid_InvalidCIDsLength.selector));
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDsWrong);
    }

    function test_setValid_InvalidNftIds() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        vm.prank(creator1, creator1);
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__setValid_InvalidNFTIDs.selector));
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTidsWrong, rewardCIDs0);
    }

    function test_setValid_Sucessful() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        vm.prank(creator1, creator1);
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        assertEq(proxyFactory1167.isValid(outputProjectId, reward0), true);
        assertEq(proxyFactory1167.indexToCID(outputProjectId, rewardNFTids0[0]), "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        assertEq(proxyFactory1167.indexToCID(outputProjectId, rewardNFTids0[1]), "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        assertEq(proxyFactory1167.indexToCID(outputProjectId, rewardNFTids0[2]), "Qmaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");

        vm.prank(creator1, creator1);
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167_setValid_RewardAlreadyValidated.selector));
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
    }

    function test_SetValid_Sucessful_Payment2Rewards() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        vm.startPrank(creator1, creator1);
        uint256 amount = 0.85 ether;
        uint256 balanceStartCreator1 = creator1.balance;
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        proxyFactory1167.setValid(outputProjectId, reward1, rewardNFTids1, rewardCIDs1);
        uint256 balanceEndCreator1 = creator1.balance;
        assertEq(balanceEndCreator1, balanceStartCreator1 + amount * 2);
        vm.stopPrank();
    }

    function test_mintRewardNFT_RewardNotSubmitted() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        vm.prank(creator1, creator1);
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        vm.prank(collector1, collector1);
        uint256 subscriptionNFTid = 3;
        uint32 wrongRewardid = 1;
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__MintReward_RewardNotSubmitted.selector));
        proxyFactory1167.mintRewardNFT(outputProjectId, wrongRewardid, subscriptionNFTid);
    }

    function test_mintRewardNFT_SubscriptionNFTinvalid() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        vm.prank(creator1, creator1);
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        vm.prank(collector1, collector2);
        uint256 wrongSubscriptionNFTid = maxBuyer;
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__MintReward_SubscriptionNFTNotValid.selector));
        proxyFactory1167.mintRewardNFT(outputProjectId, reward0, wrongSubscriptionNFTid);
    }

    function test_mintRewardNFT_NonSubscriptor() public {
        uint256 outputProjectId = helper_CreateAndSellOut();
        vm.prank(creator1, creator1);
        proxyFactory1167.setValid(outputProjectId, reward0, rewardNFTids0, rewardCIDs0);
        vm.prank(hacker, hacker);
        uint256 subscriptionNFTid = 0;
        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__MintReward_NonSubscriptor.selector));
        proxyFactory1167.mintRewardNFT(outputProjectId, reward0, subscriptionNFTid);
    }

    event ERC721Minted(address owner, uint256 nftId, uint256 nftSubscriptionId, address tokenContract, uint256 amount);

    function test_mintRewardNFT_Successful() public {
        uint256 outputProjectId = helper_CreateProject_SellOut_SubmitAllRewards();
        vm.startPrank(collector1, collector1);
        uint256 subscriptionNFTid = 0;
        uint256 tokenId = 3;
        vm.expectEmit(address(proxyFactory1167));
        emit ERC721Minted(
            collector1, tokenId, subscriptionNFTid, address(proxyFactory1167.contracts(outputProjectId)), 1
        );
        proxyFactory1167.mintRewardNFT(outputProjectId, reward0, subscriptionNFTid);

        vm.expectRevert(abi.encodeWithSelector(Factory1167.Factory1167__MintReward_AlreadyMinted.selector));
        proxyFactory1167.mintRewardNFT(outputProjectId, reward0, subscriptionNFTid);
        vm.stopPrank();
    }

    function test_allowlistMint_Sucess() public {
        uint256 outputProjectId = helper_CreateProject();
        vm.startPrank(creator1, creator1);
        proxySubscriptionManagement.setWhitelist(outputProjectId, whitelistRoot);
        proxySubscriptionManagement.setWhitelistStatus(outputProjectId, 1);
        vm.stopPrank();
        bytes32[] memory proof = whitelistMerkle.getProof(whitelistData, 0);
        uint256 amount = price + 0.069 ether;

        vm.prank(collector2);
        vm.expectRevert(
            abi.encodeWithSelector(SubscriptionManagement.SubscriptionMgmt__BuySubscription_NotWhitelisted.selector)
        );
        proxySubscriptionManagement.buySubscriptionWhitelist{ value: amount }(outputProjectId, proof);

        vm.prank(collector1);
        vm.expectEmit(address(proxySubscriptionManagement));
        emit BoughtSubscription(collector1, 0, 0, "QmX43d9EgRGaCBgxvu3FVqrFUJiijd3JcXxoXbtHHVd8rA");
        proxySubscriptionManagement.buySubscriptionWhitelist{ value: amount }(outputProjectId, proof);
    }
}
