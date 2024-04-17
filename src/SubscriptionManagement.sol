//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Factory1167.sol";
import "./Payments.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title The subscription core contract
 * @notice Allows for users to buy subscriptions, claim and set rewards
 */
contract SubscriptionManagement is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    uint16 constant basis_points = 10_000;
    uint16 public platform_fee;
    uint16 public advance_creator;
    address payable public podTreasury;
    address payable public podPayments;
    address public podNFTfactory;
    uint256 public projectsCounter;

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
    mapping(uint256 => mapping(uint256 => bool)) public paid;
    mapping(uint256 => uint256) private owner_rev;

    // projectId => collectorAddess => bool
    mapping(uint256 => mapping(address => bool)) public whitelist;
    // projectId => whitelistStatus 0 closed, 1 whitelist open, 2 public sale open
    mapping(uint256 => uint256) public whitelistStatus;
    // projectId => blocked
    mapping(uint256 => bool) public blocked;
    // projectId => Subscription CID
    mapping(uint256 => string) private _subscriptionCIDs;

    event CreateProjectAccount(uint256 id, address artist, string _name, string _symbol);
    event BuySubscription(address indexed buyer, uint256 nftId, uint256 projectId, string cid);
    event SubscriptionAllowlist(uint256 projectId, address user);

    error SubscriptionMgmt__TrasnferOwner_NotOnwer();
    error SubscriptionMgmt__BlockContract_NotOnwer();
    error SubscriptionMgmt__SetWhitelist_NotOnwer();
    error SubscriptionMgmt__setWhitelistStatus_NotOnwer();
    error SubscriptionMgmt__setWhitelistStatus_InvalidStatus();
    error SubscriptionMgmt__ClaimFunds_NotOnwer();
    error SubscriptionMgmt__ClaimFunds_RewardNotValidated();
    error SubscriptionMgmt__ClaimFunds_FundsClaimed();
    error SubscriptionMgmt__CreateProject_InvalidNameOrSymbol();
    error SubscriptionMgmt__InvalidNrSubscBuyers();
    error SubscriptionMgmt__BuySubscription_ProjectBlockedSubscription();
    error SubscriptionMgmt__BuySubscription_ProjectBlockedFactory();
    error SubscriptionMgmt__BuySubscription_SaleNotOpen();
    error SubscriptionMgmt__BuySubscription_NotWhitelisted();
    error SubscriptionMgmt__BuySubscription_NotEnoughEth();
    error SubscriptionMgmt__BuySubscription_SoldOut();
    error SubscriptionMgmt__BuySubscription_FailedETHCreator();
    error SubscriptionMgmt__BuySubscription_FailedETHPayments();
    error SubscriptionMgmt__BuySubscription_FailedETHTreasury();

    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() {
        _disableInitializers();
    }

    function initialize(address _treasury, address _payments, address _NFTDigipodFactory) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        podTreasury = payable(_treasury);
        podPayments = payable(_payments);
        podNFTfactory = _NFTDigipodFactory;
        platform_fee = 500;
        advance_creator = 1000;
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
        string calldata _backendId,
        uint8[] calldata _rewards
    )
        public
        returns (uint256)
    {
        if (_maxBuyer == 0) revert SubscriptionMgmt__InvalidNrSubscBuyers();
        (uint256 projectId, address nftContractAddress) = _deployProject(_name, _symbol, _royalty, msg.sender); // deploys
            // NFT
        _subscriptionCIDs[projectId] = _CID;
        // store key project info --> do we need all of this?
        projects[projectId] = ProjectInfo(_price, msg.sender, nftContractAddress, _maxBuyer, 0, _backendId, _rewards);
        blocked[projectId] = false; // initialize blocked
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
        nftContractAddress =
            Factory1167(podNFTfactory).deployDigipodNFTContract(_royalty, _name, _symbol, contractOnwer);
        emit CreateProjectAccount(projectsCounter++, msg.sender, _name, _symbol);
        projectId = projectsCounter - 1;
    }

    function setWhitelist(uint256 projectId, address[] memory allowlist) public {
        if (projects[projectId].projectOwner != msg.sender) revert SubscriptionMgmt__SetWhitelist_NotOnwer();
        uint256 lenght = allowlist.length;

        for (uint16 i = 0; i < lenght; i++) {
            whitelist[projectId][allowlist[i]] = true;
            emit SubscriptionAllowlist(projectId, allowlist[i]);
        }
    }

    function setWhitelistStatus(uint256 projectId, uint256 status) public {
        if (projects[projectId].projectOwner != msg.sender) revert SubscriptionMgmt__setWhitelistStatus_NotOnwer();
        if (status > 2) revert SubscriptionMgmt__setWhitelistStatus_InvalidStatus();

        whitelistStatus[projectId] = status;
    }

    /*added to input parameters: string cid (from IPFS)*/
    // months unused on pourpuse TODO - remove completly
    function buySubscription(uint256 projectId) public payable nonReentrant {
        //Require not blocked
        string memory subscriptionCID = _subscriptionCIDs[projectId];
        if (blocked[projectId]) revert SubscriptionMgmt__BuySubscription_ProjectBlockedSubscription();
        if (Factory1167(podNFTfactory).isBlocked(projectId)) {
            revert SubscriptionMgmt__BuySubscription_ProjectBlockedFactory();
        }
        if (whitelistStatus[projectId] == 0) {
            revert SubscriptionMgmt__BuySubscription_SaleNotOpen();
        } else if (whitelistStatus[projectId] == 1) {
            if (!whitelist[projectId][msg.sender]) revert SubscriptionMgmt__BuySubscription_NotWhitelisted();
            _processPurchase(projectId, subscriptionCID);
        } else if (whitelistStatus[projectId] == 2) {
            _processPurchase(projectId, subscriptionCID);
        }
    }

    function _processPurchase(uint256 projectId, string memory CID) private {
        uint256 price = projects[projectId].price;
        uint256 fees = (price * platform_fee) / basis_points;
        uint256 owner_adv = (price * advance_creator) / basis_points;
        owner_rev[projectId] = projects[projectId].price - fees - owner_adv;

        //Require that value is equal or higher to price
        if (msg.value < price) revert SubscriptionMgmt__BuySubscription_NotEnoughEth();
        if (projects[projectId].currentBuyers == projects[projectId].maxBuyers) {
            revert SubscriptionMgmt__BuySubscription_SoldOut();
        }

        (bool success0,) = payable(projects[projectId].projectOwner).call{ value: owner_adv }("");
        if (!success0) revert SubscriptionMgmt__BuySubscription_FailedETHCreator();
        (bool success1,) = podPayments.call{ value: owner_rev[projectId] }("");
        if (!success1) revert SubscriptionMgmt__BuySubscription_FailedETHPayments();
        (bool success2,) = podTreasury.call{ value: fees }("");
        if (!success2) revert SubscriptionMgmt__BuySubscription_FailedETHTreasury();

        uint256 nftId = projects[projectId].currentBuyers;
        Factory1167(podNFTfactory).mintSubscriptionNFT(projectId, nftId, CID); // mint NFT reward
        projects[projectId].currentBuyers++;
        emit BuySubscription(msg.sender, nftId, projectId, CID);
    }

    function getTypeRewards(uint256 projectId) external view returns (uint8[] memory) {
        return projects[projectId].rewards;
    }

    function getProject(uint256 _project) public view returns (ProjectInfo memory) {
        return projects[_project];
    }

    function transferOwnership(uint256 projectId, address newOwner) public {
        // TO DO: fix this, we should change onwer of actual contract, otherwise is just an ADMIN
        if (projects[projectId].projectOwner != msg.sender) revert SubscriptionMgmt__TrasnferOwner_NotOnwer();
        projects[projectId].projectOwner = newOwner;
    }

    function blockContract(uint256 projectId) public {
        if (projects[projectId].projectOwner != msg.sender) revert SubscriptionMgmt__BlockContract_NotOnwer();
        Factory1167(podNFTfactory).blockContract(projectId);
        blocked[projectId] = true;
    }

    function setFees(uint16 _platform_fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        platform_fee = _platform_fee;
    }

    function setAdvanceCreator(uint16 _advance_creator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        advance_creator = _advance_creator;
    }

    // REMOVED REFUND FROM THIS VERSION
    function claimFunds(uint256 projectId, uint32 rewardId) public {
        // think there is a loophole here
        if (
            !(
                projects[projectId].projectOwner == msg.sender
                    && Factory1167(podNFTfactory).indexToOwner(projectId) == msg.sender
            )
        ) {
            revert SubscriptionMgmt__ClaimFunds_NotOnwer();
        }
        if (!Factory1167(podNFTfactory).isValid(projectId, rewardId)) {
            revert SubscriptionMgmt__ClaimFunds_RewardNotValidated();
        }
        if (paid[projectId][rewardId]) {
            revert SubscriptionMgmt__ClaimFunds_FundsClaimed();
        }
        uint256 totalRewards = projects[projectId].rewards.length;
        // uint256 amount = Math.div(Math.sub(price, fees), total); //(price - fees) / total;
        //updated for 0.8.20
        uint256 amount = owner_rev[projectId] / totalRewards;
        Payments(podPayments).withdraw(payable(msg.sender), amount);
        paid[projectId][rewardId] = true;
    }

    function isValidId(uint256 projectId, uint256 id) public view returns (bool) {
        return (id >= 0 && id < projects[projectId].maxBuyers);
    }
}
