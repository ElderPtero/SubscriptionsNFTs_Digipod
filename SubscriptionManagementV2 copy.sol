//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Payments.sol";
import "./Rewards1167.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
/**
 * @title The subscription core contract
 * @notice Allows for users to buy subscriptions, claim and set rewards
 */

contract SubscriptionManagementV2 is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    uint16 constant basis_points = 10_000;
    uint16 public platform_fee;
    uint16 public advance_creator;
    address payable public podPayments;
    uint256 public projectsCounter;
    uint256 public mintFee;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    address public contractBase;
    string internal prefix_CID;

    Rewards1167[] public contracts; //an array that contains different ERC721 contracts deployed

    /// @notice id -> The Project Id
    /// @notice nftContract --> address of the project NFT contract
    /// @notice backendId -> POD backend id // this should not be needed
    /// @notice maxBuyers -> nr of max subscription NFTs
    /// @notice currentBuyers -> nr of existing subscription NFTs
    /// @notice rewards -> nr of different type of rewards
    /// @notice price -> price subscription

    struct ProjectInfo {
        uint256 price;
        address projectOwner;
        address nftContract;
        uint32 maxBuyers;
        uint32 currentBuyers;
        string backendId;
        uint8[] rewards;
    }

    mapping(uint256 => ProjectInfo) public projects;
    //projectId => rewardId => bool
    mapping(uint256 => uint256) public maxMint;
    mapping(uint256 => mapping(address => uint256)) public nftsMinted;
    mapping(uint256 => bytes32) private whitelistMerkleRoot;
    mapping(uint256 => uint256) private owner_rev;
    // projectId => whitelistStatus 0 closed, 1 whitelist open, 2 public sale open
    mapping(uint256 => uint256) public whitelistStatus;
    // projectId => Subscription CID
    mapping(uint256 => string) private _subscriptionCIDs;
    // projectId, RewardId, bool
    mapping(uint256 => mapping(uint32 => bool)) public rewardSubmitted;
    //mapping(uint256 => mapping(uint256 => address)) public indexToBuyer; //index to ERC-721 buyer address
    mapping(uint256 => mapping(uint256 => string)) public indexToCID; //index to ERC-721 CID
    //[projectId][tierId][rewardId]++;
    mapping(uint256 => mapping(uint32 => uint256)) private rewardCounter;
    //projectId -> subscriptionId => rewardsId => bool
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) private userMintedRewards;

    event CreatedProjectAccount(uint256 id, address artist, string _name, string _symbol);
    event BoughtSubscription(
        address indexed buyer, uint256[] nftId, uint256 projectId, string cid, uint256 amountMinted
    );
    event SubscriptionAllowlist(uint256 projectId, address user);
    event ERC721Created(address owner, address tokenContract); //emited when ERC721 token is deployed
    event ERC721Minted(address owner, uint256 nftId, uint256 nftSubscriptionId, address tokenContract, uint256 amount); //emmited
        // when ERC721 token is minted

    error SubscriptionMgmt__BlockContract_AlreadyBlocked();
    error SubscriptionMgmt__setWhitelistStatus_InvalidStatus();
    error SubscriptionMgmt__CreateProject_InvalidNameOrSymbol();
    error SubscriptionMgmt__InvalidNrSubscBuyers();
    error SubscriptionMgmt__BuySubscriptionWhitelist_InvalidProof();
    error SubscriptionMgmt__BuySubscription_ProjectBlockedFactory();
    error SubscriptionMgmt__BuySubscription_SaleNotOpen();
    error SubscriptionMgmt__BuySubscription_NotEnoughEth();
    error SubscriptionMgmt__BuySubscription_SoldOut();
    error SubscriptionMgmt__BuySubscription_FailedETHCreator();
    error SubscriptionMgmt__BuySubscription_FailedETHPayments();
    error SubscriptionMgmt__setValid_ProjectNotClosed();
    error SubscriptionMgmt__setValid_InvalidCIDsLength();
    error SubscriptionMgmt__setValid_InvalidRewardId();
    error SubscriptionMgmt__setValid_nftIdsNotMatchSubscriptionNr();
    error SubscriptionMgmt__setValid_InvalidNFTIDs();
    error SubscriptionMgmt__setValid_RewardAlreadyValidated();
    error SubscriptionMgmt__InvalidSubscriptionNFTId();
    error SubscriptionMgmt__MintReward_SubscriptionNFTNotValid();
    error SubscriptionMgmt__MintReward_NonSubscriptor();
    error SubscriptionMgmt__MintReward_RewardNotSubmitted();
    error SubscriptionMgmt__MintReward_AlreadyMinted();
    error SubscriptionMgmt__NotProjectOnwer();
    error SubscriptionMgmt__BuySubscription_NotEnoughNFTsForSale();
    error SubscriptionMgmt__BuySubscription_UserMaxMintReach();
    error SubscriptionMgmt__BuySubscription_InvalidAmount0();
    error SubscriptionMgmt__BuySubscription_CurrentMintAboveMaxMintAllowed();

    modifier onlyProjectOwner(uint256 _projectId) {
        if (projects[_projectId].projectOwner != msg.sender) revert SubscriptionMgmt__NotProjectOnwer();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() {
        _disableInitializers();
    }

    function initialize(address _payments, address baseERC721contract) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        contractBase = baseERC721contract;
        podPayments = payable(_payments);
        platform_fee = 500;
        //mintFee = 0;
        advance_creator = 1000;
        prefix_CID = "ipfs://"; //CHANGE TO GATEWAY
    }

    // To explore: add a Initial Onwer parameter who will take onwership of nft contract -> allows to create things for
    // other people.
    function createProject(
        string calldata _name,
        string calldata _symbol,
        string calldata _CID,
        uint16 _royalty,
        uint256 _price,
        uint16 _maxBuyer,
        uint16 _maxMint,
        string calldata _backendId,
        uint8[] calldata _rewards
    )
        public
        returns (uint256)
    {
        if (_maxBuyer == 0) revert SubscriptionMgmt__InvalidNrSubscBuyers();
        (uint256 projectId, address nftContractAddress) = _deployProject(_name, _symbol, _royalty, msg.sender); // deploys
            // NFT
        _subscriptionCIDs[projectId] = string(abi.encodePacked(prefix_CID, _CID));
        maxMint[projectId] = _maxMint;
        // store key project info --> do we need all of this?
        projects[projectId] = ProjectInfo(_price, msg.sender, nftContractAddress, _maxBuyer, 0, _backendId, _rewards);
        // might want to emit project creation instead of all this/ TBSEEN
        return projectId;
    }

    function _deployProject(
        string memory _name,
        string memory _symbol,
        uint16 _royalty,
        address contractOnwer
    )
        internal // changed to private to avoid people can call it
        returns (uint256 projectId, address nftContractAddress)
    {
        //Check if name and symbol are valid
        if (!(bytes(_name).length > 0 && bytes(_symbol).length > 0)) {
            revert SubscriptionMgmt__CreateProject_InvalidNameOrSymbol();
        }
        Rewards1167 newRewardContract = Rewards1167(Clones.clone(contractBase));
        newRewardContract.initialize(payable(contractOnwer), _royalty, _name, _symbol, contractOnwer);
        contracts.push(newRewardContract);
        emit ERC721Created(msg.sender, address(newRewardContract));
        emit CreatedProjectAccount(projectsCounter++, contractOnwer, _name, _symbol); // changed contractOnwer to
            // contractOnwer
        projectId = projectsCounter - 1;
        nftContractAddress = address(newRewardContract);
    }

    function setWhitelist(uint256 projectId, bytes32 _whitelistMerkleRoot) public onlyProjectOwner(projectId) {
        whitelistMerkleRoot[projectId] = _whitelistMerkleRoot;
    }

    function setWhitelistStatus(uint256 projectId, uint256 status) public onlyProjectOwner(projectId) {
        if (status > 2) revert SubscriptionMgmt__setWhitelistStatus_InvalidStatus();
        whitelistStatus[projectId] = status;
    }

    function buySubscriptionWhitelist(
        uint256 projectId,
        bytes32[] memory _proof,
        uint256 mintAmount
    )
        public
        payable
        nonReentrant
    {
        //Require not blocked
        if (mintAmount == 0) revert SubscriptionMgmt__BuySubscription_InvalidAmount0();
        if (isBlocked(projectId)) {
            revert SubscriptionMgmt__BuySubscription_ProjectBlockedFactory();
        }
        if (projects[projectId].currentBuyers == projects[projectId].maxBuyers) {
            revert SubscriptionMgmt__BuySubscription_SoldOut();
        }
        if (whitelistStatus[projectId] == 0 || whitelistStatus[projectId] == 2) {
            revert SubscriptionMgmt__BuySubscription_SaleNotOpen();
        } else if (whitelistStatus[projectId] == 1) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            if (!MerkleProof.verify(_proof, whitelistMerkleRoot[projectId], leaf)) {
                revert SubscriptionMgmt__BuySubscriptionWhitelist_InvalidProof();
            }
            if (projects[projectId].currentBuyers + mintAmount > projects[projectId].maxBuyers) {
                // CHECK EDGE NUMBER
                revert SubscriptionMgmt__BuySubscription_NotEnoughNFTsForSale();
            }
            if (nftsMinted[projectId][msg.sender] + mintAmount > maxMint[projectId]) {
                // CHECK EDGE NUMBER
                revert SubscriptionMgmt__BuySubscription_CurrentMintAboveMaxMintAllowed();
            }
            _processPurchase(projectId, _subscriptionCIDs[projectId], mintAmount);
        }
    }

    function buySubscription(uint256 projectId, uint256 mintAmount) public payable nonReentrant {
        //Require not blocked
        if (mintAmount == 0) revert SubscriptionMgmt__BuySubscription_InvalidAmount0();
        if (isBlocked(projectId)) {
            revert SubscriptionMgmt__BuySubscription_ProjectBlockedFactory();
        }
        if (projects[projectId].currentBuyers == projects[projectId].maxBuyers) {
            revert SubscriptionMgmt__BuySubscription_SoldOut();
        }
        if (whitelistStatus[projectId] == 0 || whitelistStatus[projectId] == 1) {
            revert SubscriptionMgmt__BuySubscription_SaleNotOpen();
        }
        if (projects[projectId].currentBuyers + mintAmount > projects[projectId].maxBuyers) {
            // CHECK EDGE NUMBER
            revert SubscriptionMgmt__BuySubscription_NotEnoughNFTsForSale();
        }
        _processPurchase(projectId, _subscriptionCIDs[projectId], mintAmount);
    }

    function _processPurchase(uint256 projectId, string memory CID, uint256 mintAmount) private {
        uint256 price = projects[projectId].price;
        uint256 fees = (price * platform_fee) / basis_points;
        uint256 owner_adv = (price * advance_creator) / basis_points;
        owner_rev[projectId] = projects[projectId].price - fees - owner_adv;
        uint256 totalPayable = (price + mintFee) * mintAmount;
        //Require that value is equal or higher to price
        if (msg.value < totalPayable) revert SubscriptionMgmt__BuySubscription_NotEnoughEth();

        (bool success0,) = payable(projects[projectId].projectOwner).call{ value: owner_adv * mintAmount }("");
        if (!success0) revert SubscriptionMgmt__BuySubscription_FailedETHCreator();
        (bool success1,) = podPayments.call{ value: owner_rev[projectId] * mintAmount }("");
        if (!success1) revert SubscriptionMgmt__BuySubscription_FailedETHPayments();
        uint256 nftId = projects[projectId].currentBuyers;
        uint256[] memory nftIDsBatched = new uint256[](mintAmount);
        for (uint256 i = 0; i < mintAmount; i++) {
            nftIDsBatched[i] = nftId + i;
            _mintSubscriptionNFT(projectId, nftId + i, CID);
        }
        nftsMinted[projectId][msg.sender] = nftsMinted[projectId][msg.sender] + mintAmount;
        projects[projectId].currentBuyers = projects[projectId].currentBuyers + uint32(mintAmount);
        emit BoughtSubscription(msg.sender, nftIDsBatched, projectId, CID, mintAmount);
    }

    function _mintSubscriptionNFT(uint256 projectId, uint256 tokenSubscriptionId, string memory tokenURI) internal {
        if (!(isValidId(projectId, tokenSubscriptionId))) {
            revert SubscriptionMgmt__InvalidSubscriptionNFTId();
        }
        contracts[projectId].safeMint(tx.origin, tokenSubscriptionId, tokenURI);
    }

    function blockContract(uint256 projectId) public onlyProjectOwner(projectId) {
        if (isBlocked(projectId)) revert SubscriptionMgmt__BlockContract_AlreadyBlocked();
        contracts[projectId].toBlock();
    }

    function setValid(
        uint256 projectId,
        uint32 rewardId,
        uint256[] memory nftIds,
        string[] memory CIDs
    )
        public
        onlyProjectOwner(projectId)
    {
        ProjectInfo memory projectInfo = getProject(projectId);
        if (!isBlocked(projectId) && projectInfo.currentBuyers != projectInfo.maxBuyers) {
            // project not closed
            revert SubscriptionMgmt__setValid_ProjectNotClosed();
        }
        if (rewardId >= projectInfo.rewards.length) revert SubscriptionMgmt__setValid_InvalidRewardId(); // reward
            // invalid
        if (nftIds.length != projectInfo.currentBuyers) {
            revert SubscriptionMgmt__setValid_nftIdsNotMatchSubscriptionNr();
        }
        //add check if reward has been validated already
        if (nftIds.length != CIDs.length) revert SubscriptionMgmt__setValid_InvalidCIDsLength();
        // ids and CIDs not matching
        uint256 length = nftIds.length;
        uint256 lowerNFTid = projectInfo.maxBuyers + (rewardId * projectInfo.currentBuyers);
        uint256 maxNFTid = lowerNFTid + projectInfo.currentBuyers - 1;
        if (rewardSubmitted[projectId][rewardId]) revert SubscriptionMgmt__setValid_RewardAlreadyValidated(); // reward
        for (uint32 i; i < length; i++) {
            if (nftIds[i] < lowerNFTid || nftIds[i] > maxNFTid) revert SubscriptionMgmt__setValid_InvalidNFTIDs(); // check
            indexToCID[projectId][nftIds[i]] = string(abi.encodePacked(prefix_CID, CIDs[i]));
        }
        rewardSubmitted[projectId][rewardId] = true;
        uint256 payablePerReward = getPayablePerReward(projectId);
        Payments(podPayments).withdraw(payable(msg.sender), payablePerReward);
    }

    /* When claim by collector */
    function mintRewardNFT(
        uint256 projectId,
        uint32 rewardId,
        uint256 tokenSubscriptionId
    )
        public
        payable
        nonReentrant
    {
        if (!rewardSubmitted[projectId][rewardId]) revert SubscriptionMgmt__MintReward_RewardNotSubmitted();
        ProjectInfo memory projectInfo = getProject(projectId);
        if (!isValidId(projectId, tokenSubscriptionId)) {
            revert SubscriptionMgmt__MintReward_SubscriptionNFTNotValid();
        }
        if (contracts[projectId].ownerOf(tokenSubscriptionId) != msg.sender) {
            revert SubscriptionMgmt__MintReward_NonSubscriptor();
        }
        if (userMintedRewards[projectId][tokenSubscriptionId][rewardId]) {
            revert SubscriptionMgmt__MintReward_AlreadyMinted();
        }
        if (msg.value < mintFee) revert SubscriptionMgmt__BuySubscription_NotEnoughEth();
        uint256 tokenId =
            projectInfo.maxBuyers + (rewardId * projectInfo.currentBuyers) + rewardCounter[projectId][rewardId]++;
        userMintedRewards[projectId][tokenSubscriptionId][rewardId] = true;
        contracts[projectId].safeMint(msg.sender, tokenId, indexToCID[projectId][tokenId]);
        emit ERC721Minted(msg.sender, tokenId, tokenSubscriptionId, address(contracts[projectId]), 1);
    }

    function isValidId(uint256 projectId, uint256 id) internal view returns (bool) {
        return (id >= 0 && id < projects[projectId].maxBuyers);
    }

    function isBlocked(uint256 projectId) public view returns (bool) {
        return contracts[projectId].blocked();
    }

    function getTypeRewards(uint256 _projectId) external view returns (uint8[] memory) {
        return projects[_projectId].rewards;
    }

    function getProject(uint256 _projectId) public view returns (ProjectInfo memory) {
        return projects[_projectId];
    }

    function getPayablePerReward(uint256 _projectId) public view returns (uint256) {
        return projects[_projectId].currentBuyers * owner_rev[_projectId] / projects[_projectId].rewards.length;
    }

    function updatePlataformFees(uint16 _platform_fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        platform_fee = _platform_fee;
    }

    function updateMintFee(uint256 newMintFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintFee = newMintFee;
    }

    function setAdvanceCreator(uint16 _advance_creator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        advance_creator = _advance_creator;
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
        require(success);
    }
}
