//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ITokenAllocator.sol";

/**
 * @dev Interface for interacting with the Allo token.
 */
interface IERC20 {
    function transfer(address _To, uint256 _Amount) external;
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external;
    function mint(address to, uint256 amount) external;
}

contract TokenAllocator is Pausable, AccessManaged, ReentrancyGuard {
    int8 public lastMintedStage;
    int8 public currentStage;
    IERC20 public Allo;

    address public contentAddress; //Content platform's wallet/smartContrcat adderss
    address public devInfraAddress; //Development of infrastructure's wallet/smartContrcat adderss
    address public treasuryAddress; //Treasury's wallet address

    // Constant variables for allocation amounts
    uint256 private constant CONTENT_INFRADEV_ALLOCATED_STAGE_0 = 12500000000000000000000000;
    uint256 private constant CONTENT_INFRADEV_ALLOCATED_STAGE_1 = 17500000000000000000000000;
    uint256 private constant CONTENT_INFRADEV_ALLOCATED_STAGE_2 = 30000000000000000000000000;
    uint256 private constant CONTENT_INFRADEV_ALLOCATED_STAGE_3 = 40000000000000000000000000;
    uint256 private constant CONTENT_INFRADEV_ALLOCATED_STAGE_4_5 = 50000000000000000000000000;
    uint256 private constant CONTENT_INFRADEV_ALLOCATED_STAGE_OTHER = 60000000000000000000000000;
    uint256 private constant TREASURY_ALLOCATION_FIRST_PART = 140000000000000000000000000;
    uint256 private constant TREASURY_ALLOCATION_SECOND_PART = 150000000000000000000000000;

    // Mapping to check if the reward has been transferred or not
    mapping(int8 => bool) rewardCondition;

    enum Recipients {
        Content, // 0
        DevInfra, // 1
        Treasury // 2

    }

    // Events
    event NewStageTokensMinted(int8 stage, uint256 amount);
    event DAOStageChanged(int8 stage);
    event ContentRewarded(address contentAddress, int8 stage, uint256 rewardAmount);
    event DevInfraRewarded(address devInfraAddress, int8 stage, uint256 rewardAmount);
    event TreasuryRewarded(address treasuryAddress, int8 stage, uint256 rewardAmount);

    /**
     * @dev Initializes the Content contract.
     * @param initialAuthority The initial authority for AccessManaged.
     * @param AlloAddr The address of the Allo token contract.
     */
    constructor(address initialAuthority, address payable AlloAddr) AccessManaged(initialAuthority) {
        Allo = IERC20(AlloAddr);
        lastMintedStage = -1;
        currentStage = -1;
        rewardCondition[-1] = true;
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() public restricted {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() public restricted {
        _unpause();
    }

    /**
     * @dev The admin changes the current stage.
     * @param targetStage The target stage to change to.
     */
    function changeStage(int8 targetStage) external restricted whenNotPaused {
        require(targetStage <= 10, "Target stage exceeds maximum stage");
        require(targetStage == (currentStage + 1), "Target stage must be next stage");
        require(rewardCondition[targetStage - 1] == true, "The last stage has not been awarded!");
        require(
            (contentAddress != address(0)) && (devInfraAddress != address(0)) && (treasuryAddress != address(0)),
            "All addresses must be set"
        );

        currentStage = targetStage;
        mintStageTokens();

        emit DAOStageChanged(currentStage);
    }

    /**
     * @dev Sets the addresses for the various roles.
     * @param _contentAddress The address for the Content platform.
     * @param _devInfraAddress The address for the Development of infrastructure.
     * @param _treasuryAddress The address for the Treasury.
     */
    function setAddress(address _contentAddress, address _devInfraAddress, address _treasuryAddress)
        external
        restricted
        whenNotPaused
    {
        require(
            (_contentAddress != address(0)) && (_devInfraAddress != address(0)) && (_treasuryAddress != address(0)),
            "All addresses must be set"
        );
        contentAddress = _contentAddress;
        devInfraAddress = _devInfraAddress;
        treasuryAddress = _treasuryAddress;
    }

    /**
     * @dev Sets the address for a specific recipient.
     * @param _recipients The recipients type.
     * @param _addr The address to set.
     */
    function setAddress(Recipients _recipients, address _addr) external restricted whenNotPaused {
        require(_addr != address(0), "Address cannot be zero");
        if (_recipients == Recipients.Content) {
            contentAddress = _addr;
        } else if (_recipients == Recipients.DevInfra) {
            devInfraAddress = _addr;
        } else if (_recipients == Recipients.Treasury) {
            treasuryAddress = _addr;
        } else {
            revert("All addresses have been set");
        }
    }

    /**
     * @dev Transfers the reward to the respective addresses for the current stage.
     */
    function txReward() external restricted whenNotPaused nonReentrant {
        int8 stage = currentStage;

        require(stage >= 0 && stage <= 10, "Stage must be in range");
        require(rewardCondition[stage] == false, "The reward has been transferred in this stage!");
        rewardCondition[stage] = true;

        // Content reward
        uint256 contentReward;
        if (stage == 0) {
            contentReward = CONTENT_INFRADEV_ALLOCATED_STAGE_0;
        } else if (stage == 1) {
            contentReward = CONTENT_INFRADEV_ALLOCATED_STAGE_1;
        } else if (stage == 2) {
            contentReward = CONTENT_INFRADEV_ALLOCATED_STAGE_2;
        } else if (stage == 3) {
            contentReward = CONTENT_INFRADEV_ALLOCATED_STAGE_3;
        } else if (stage == 4 || stage == 5) {
            contentReward = CONTENT_INFRADEV_ALLOCATED_STAGE_4_5;
        } else {
            contentReward = CONTENT_INFRADEV_ALLOCATED_STAGE_OTHER;
        }
        Allo.transfer(contentAddress, contentReward);
        emit ContentRewarded(contentAddress, stage, contentReward);

        // Development of Allostasis infrastructure reward
        uint256 devInfraReward;
        if (stage == 0) {
            devInfraReward = CONTENT_INFRADEV_ALLOCATED_STAGE_0;
        } else if (stage == 1) {
            devInfraReward = CONTENT_INFRADEV_ALLOCATED_STAGE_1;
        } else if (stage == 2) {
            devInfraReward = CONTENT_INFRADEV_ALLOCATED_STAGE_2;
        } else if (stage == 3) {
            devInfraReward = CONTENT_INFRADEV_ALLOCATED_STAGE_3;
        } else if (stage == 4 || stage == 5) {
            devInfraReward = CONTENT_INFRADEV_ALLOCATED_STAGE_4_5;
        } else {
            devInfraReward = CONTENT_INFRADEV_ALLOCATED_STAGE_OTHER;
        }
        Allo.transfer(devInfraAddress, devInfraReward);
        emit ContentRewarded(devInfraAddress, stage, devInfraReward);

        // Treasury reward
        uint256 treasuryReward = (stage >= 0 && stage <= 3)
            ? 0
            : (stage >= 4 && stage <= 8) ? TREASURY_ALLOCATION_FIRST_PART : TREASURY_ALLOCATION_SECOND_PART;
        Allo.transfer(treasuryAddress, treasuryReward);
        emit TreasuryRewarded(treasuryAddress, stage, treasuryReward);
    }

    /**
     * @dev Mints tokens for the current stage.
     */
    function mintStageTokens() private {
        int8 stage = currentStage;
        uint256 mintAmount;
        require(lastMintedStage < stage, "Tokens for the current stage have already been minted");
        if (stage == 0) {
            mintAmount = 2 * CONTENT_INFRADEV_ALLOCATED_STAGE_0;
        } else if (stage == 1) {
            mintAmount = 2 * CONTENT_INFRADEV_ALLOCATED_STAGE_1;
        } else if (stage == 2) {
            mintAmount = 2 * CONTENT_INFRADEV_ALLOCATED_STAGE_2;
        } else if (stage == 3) {
            mintAmount = 2 * CONTENT_INFRADEV_ALLOCATED_STAGE_3;
        } else if (stage == 4 || stage == 5) {
            mintAmount = 2 * CONTENT_INFRADEV_ALLOCATED_STAGE_4_5;
        } else {
            mintAmount = 2 * CONTENT_INFRADEV_ALLOCATED_STAGE_OTHER;
        }

        uint256 mintForTreasury = (stage >= 0 && stage <= 3)
            ? 0
            : (stage >= 4 && stage <= 8) ? TREASURY_ALLOCATION_FIRST_PART : TREASURY_ALLOCATION_SECOND_PART;
        Allo.mint(address(this), mintAmount + mintForTreasury);
        lastMintedStage += 1;

        emit NewStageTokensMinted(stage, mintAmount);
    }
}
