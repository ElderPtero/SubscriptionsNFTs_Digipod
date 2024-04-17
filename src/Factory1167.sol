// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Rewards1167.sol";
import "./SubscriptionManagement.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract Factory1167 is Initializable, AccessControlUpgradeable {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    address public subscriptionAddress;
    Rewards1167[] public contracts; //an array that contains different ERC721 contracts deployed

    // projectId, RewardId, bool
    mapping(uint256 => mapping(uint32 => bool)) public rewardValid;
    mapping(uint256 => address) public indexToOwner; //index to ERC721 owner address
    //mapping(uint256 => mapping(uint256 => address)) public indexToBuyer; //index to ERC-721 buyer address
    mapping(uint256 => mapping(uint256 => string)) public indexToCID; //index to ERC-721 CID
    //[projectId][tierId][rewardId]++;
    mapping(uint256 => mapping(uint32 => uint256)) public rewardCounter;
    //projectId -> subscriptionId => rewardsId => bool
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) public userMintedRewards;
    address public contractBase;

    struct ProjectInfo {
        uint256 price;
        address projectOwner;
        address nftContract;
        uint32 maxBuyers;
        uint32 currentBuyers;
        string backendId;
        uint8[] rewards;
    }

    event ERC721Created(address owner, address tokenContract); //emited when ERC721 token is deployed
    event ERC721Minted(address owner, uint256 nftId, uint256 nftSubscriptionId, address tokenContract, uint256 amount); //emmited
        // when ERC721 token is minted

    error Factory1167__BlockingByNonOnwer();
    error Factory1167__setValid_ProjectNotClosed();
    error Factory1167__setValid_NotOnwer();
    error Factory1167__setValid_InvalidArrayLength();
    error Factory1167__setValid_InvalidRewardId();
    error Factory1167__setValid_nftIdsNotMatchSubscriptionNr();
    error Factory1167__setValid_InvalidNFTIDs();
    error Factory1167_setValid_RewardAlreadyValidated();
    error Factory1167__InvalidSubscriptionNFTId();
    error Factory1167__MintReward_ProjectNotClosed();
    error Factory1167__MintReward_SubscriptionNFTNotValid();
    error Factory1167__MintReward_NonSubscriptor();
    error Factory1167__MintReward_RewardNotValid();
    error Factory1167__MintReward_AlreadyMinted();
    error Factory1167__MintReward_AllRewardsHaveBeenMinted();
    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() {
        _disableInitializers();
    }

    function initialize(address base) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        contractBase = base;
    }

    function setContractBase(address base) public onlyRole(DEFAULT_ADMIN_ROLE) {
        contractBase = base;
    }

    function blockContract(uint256 projectId) public {
        if (indexToOwner[projectId] != tx.origin) revert Factory1167__BlockingByNonOnwer(); // TO TEST PROPERLY,
            // tx.origin because can be called from subscriptionManagement.
        contracts[projectId].toBlock();
    }

    function isBlocked(uint256 projectId) public view returns (bool) {
        return contracts[projectId].blocked();
    }

    function setSubscriptionAddress(address _subscription) public onlyRole(DEFAULT_ADMIN_ROLE) {
        subscriptionAddress = _subscription;
    }

    function deployDigipodNFTContract(
        uint16 royalty,
        string memory name,
        string memory symbol,
        address contractOnwer
    )
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address)
    {
        Rewards1167 t = Rewards1167(Clones.clone(contractBase));
        t.initialize(payable(contractOnwer), royalty, name, symbol, contractOnwer);
        contracts.push(t);
        indexToOwner[contracts.length - 1] = contractOnwer;
        emit ERC721Created(tx.origin, address(t));
        return address(t);
    }

    function setValid(uint256 projectId, uint32 rewardId, uint256[] memory nftIds, string[] memory CIDs) public {
        if (indexToOwner[projectId] != msg.sender) revert Factory1167__setValid_NotOnwer(); // not onwer
        SubscriptionManagement.ProjectInfo memory projectInfo =
            SubscriptionManagement(subscriptionAddress).getProject(projectId);
        if (!isBlocked(projectId) || projectInfo.currentBuyers != projectInfo.maxBuyers) {
            // project not closed
            revert Factory1167__setValid_ProjectNotClosed();
        }
        if (rewardId >= projectInfo.rewards.length) revert Factory1167__setValid_InvalidRewardId(); // reward invalid
        if (nftIds.length != projectInfo.currentBuyers) revert Factory1167__setValid_nftIdsNotMatchSubscriptionNr();
        //add check if reward has been validated already
        if (nftIds.length != CIDs.length) revert Factory1167__setValid_InvalidArrayLength();
        // ids and CIDs not matching
        uint256 length = nftIds.length;
        uint256 lowerNFTid = projectInfo.maxBuyers + (rewardId * projectInfo.currentBuyers);
        uint256 maxNFTid = lowerNFTid + projectInfo.currentBuyers - 1;
        if (rewardValid[projectId][rewardId]) revert Factory1167_setValid_RewardAlreadyValidated(); // reward
        for (uint32 i; i < length; i++) {
            if (nftIds[i] < lowerNFTid || nftIds[i] > maxNFTid) revert Factory1167__setValid_InvalidNFTIDs(); // check
            indexToCID[projectId][nftIds[i]] = CIDs[i];
        }
        rewardValid[projectId][rewardId] = true;
    }

    /* When claim by collector */
    function mintRewardNFT(uint256 projectId, uint32 rewardId, uint256 tokenSubscriptionId) public {
        SubscriptionManagement.ProjectInfo memory projectInfo =
            SubscriptionManagement(subscriptionAddress).getProject(projectId);
        if (!isBlocked(projectId) || projectInfo.currentBuyers != projectInfo.maxBuyers) {
            revert Factory1167__MintReward_ProjectNotClosed();
        }
        if (userMintedRewards[projectId][tokenSubscriptionId][rewardId]) {
            revert Factory1167__MintReward_AlreadyMinted();
        }
        if (!SubscriptionManagement(subscriptionAddress).isValidId(projectId, tokenSubscriptionId)) {
            revert Factory1167__MintReward_SubscriptionNFTNotValid();
        }

        if (contracts[projectId].ownerOf(tokenSubscriptionId) != msg.sender) {
            revert Factory1167__MintReward_NonSubscriptor();
        }

        if (!rewardValid[projectId][rewardId]) revert Factory1167__MintReward_RewardNotValid();

        uint256 tokenId =
            projectInfo.maxBuyers + (rewardId * projectInfo.currentBuyers) + rewardCounter[projectId][rewardId]++;
        userMintedRewards[projectId][tokenSubscriptionId][rewardId] = true;
        contracts[projectId].safeMint(msg.sender, tokenId, indexToCID[projectId][tokenId]);
        emit ERC721Minted(msg.sender, tokenId, tokenSubscriptionId, address(contracts[projectId]), 1);
    }

    function isValid(uint256 projectId, uint32 reward_id) public view returns (bool) {
        return rewardValid[projectId][reward_id];
    }

    function ownerOf(uint256 projectId, uint256 nftId) external view returns (address) {
        return contracts[projectId].ownerOf(nftId);
    }

    function burn(uint256 projectId, uint256 nftId) external {
        contracts[projectId].burn(nftId);
    }

    function transfer(uint256 projectId, address from, address to, uint256 tokenId) external {
        contracts[projectId].safeTransferFrom(from, to, tokenId);
    }

    function getTypeRewards(uint256 projectId) public view returns (uint8[] memory) {
        return SubscriptionManagement(subscriptionAddress).getTypeRewards(projectId);
    }

    function mintSubscriptionNFT(
        uint256 projectId,
        uint256 tokenSubscriptionId,
        string memory tokenURI
    )
        external
        onlyRole(DEPLOYER_ROLE)
    {
        // add a check if the NFT has been minted or not
        // change this logic so that NFT ID is specific to a particular contract
        if (!(SubscriptionManagement(subscriptionAddress).isValidId(projectId, tokenSubscriptionId))) {
            revert Factory1167__InvalidSubscriptionNFTId();
        }
        contracts[projectId].safeMint(tx.origin, tokenSubscriptionId, tokenURI);
    }

    function getuserMintedRewards(
        uint256 projectId,
        uint256 nftSubscriptionId,
        uint256 rewardId
    )
        public
        view
        returns (bool)
    {
        return userMintedRewards[projectId][nftSubscriptionId][rewardId];
    }

    function getInstanceAddress(uint256 projectId) public view returns (address _contract) {
        Rewards1167 contractProject = contracts[projectId];
        return address(contractProject);
    }
}
