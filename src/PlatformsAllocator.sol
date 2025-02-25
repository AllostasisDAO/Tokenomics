// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/manager/AccessManaged.sol";

/**
 * @title ERC20 interface for ALLO token
 * @author Centeria Team
 * @dev This interface defines functions for interacting with the ALLO token contract.
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function mint(address to, uint256 amount) external;
}

/**
 * @title Platforms Tokens Allocator
 * @author Centeria Team
 * @dev This contract manages the Allostasis Platforms tokenomics.
 */
contract PlatformsAllocator is Pausable, AccessManaged {
    /**
     * @dev Structure containing information about each platform
     */
    struct PlatformInfo {
        string name; // Name of the platform
        address contractAddress; // Address of the platform's contract
        address admin; // Admin address of the platform
        uint256 platformId; // Unique identifier for the platform
        uint256 currentStage; // Current stage of the platform
        uint256 numberOfStages; // Total number of stages for the platform
        uint256 totalAllocated; // Total ALLO allocated to the platform
        uint256 totalFund; // Total fund allocated to the platform
        uint256[] releasePercentages; // Release percentages for each stage, add decimal last
        bool stageActivated; // Whether the current stage is activated
        bool platformActivated; // Whether the current stage token is minted
    }

    /**
     * @notice State of the contract
     * @dev the platformFactoryState in the initial is on Allostasis
     * after the number of paltforms reachs the 6, the paltformFactoryState
     * updates to Others. and remains on that state.
     */
    enum State {
        Initial,
        Allostasis,
        Others
    }

    bool _checkDeactivation; //make Reactivation of a platform only when it deactive by calling deactivePlatform

    // Events
    event NewPlatformAdded(string name, address contractAddress, address admin);
    event PlatformsTokensMinted(string name, address contractAddress, uint256 amount);
    event PlatformsStageChanged(string name, address contractAddress, uint256 currentStage);

    // Constants
    uint256 constant TOTAL_PLATFORM_ALLOCATION = 8_000_000_000; // Total ALLO tokens allocated to platforms
    uint256 private numberOfPlatforms; // Total number of registered platforms
    uint256 private decimal = 10 ** 18; // Decimal precision
    uint256 private percentageDecimal = 10 ** 11; // prcentage decimal precision (e.g. if all percentages are in decimals, we use decimal / percentageDecimal to convert between decimals
    uint256 private halving; // Counter for halving

    // Mapping to store platform information
    mapping(uint256 => PlatformInfo) public platformsInfo;

    // State variable representing the state of the platform factory
    State public platformFactoryState;

    // Instance of the ALLO token contract
    IERC20 public ALLO;

    modifier nonZeroAddress(address _admin, address _contractAddress) {
        require(_admin != address(0) && _contractAddress != address(0), "Non Zero Address.");
        _;
    }

    /**
     * @dev Constructor initializes the contract with an initial authority and ALLO token address.
     * @param initialAuthority Address of the initial authority for access control.
     * @param AlloAdr Address of the ALLO token contract.
     */
    constructor(address initialAuthority, address payable AlloAdr) AccessManaged(initialAuthority) {
        ALLO = IERC20(AlloAdr);
        platformFactoryState = State.Allostasis;
    }

    /**
     * @notice Mint ALLO tokens for a platform based on its current stage and allocation percentage.
     * @dev this function is restricted to only the platform's admins. Each admin can mint
     * tokens for its platform concerning the platform stage and stage percentage.
     * @param platformId Identifier of the platform.
     */
    function mintPlatformsTokens(uint256 platformId) external payable restricted whenNotPaused {
        require(platformsInfo[platformId].admin != address(0), "Invalid Platform Id");
        require(platformsInfo[platformId].platformActivated, "Not Activated.");
        require(!platformsInfo[platformId].stageActivated, "Already Minted.");

        PlatformInfo storage platform = platformsInfo[platformId];
        uint256[] memory _releasePercentages = platform.releasePercentages;
        uint256 releaseAmount = (_releasePercentages[platform.currentStage - 1] * platform.totalFund);
        platform.stageActivated = true;
        platform.totalAllocated += releaseAmount / 100_00000;

        _checkForEnd(platformId);
        ALLO.mint(platform.contractAddress, releaseAmount * percentageDecimal);

        emit PlatformsTokensMinted(platform.name, platform.contractAddress, releaseAmount * percentageDecimal);
    }

    /**
     * @dev Register a new platform with the specified parameters.
     * @param name Name of the platform.
     * @param contractAddress Address of the platform's contract.
     * @param admin Admin address of the platform.
     * @param _releasePercentages Release percentages for each stage.
     */
    function registerPlatform(
        string memory name,
        address contractAddress,
        address admin,
        uint256[] memory _releasePercentages
    ) external restricted nonZeroAddress(admin, contractAddress) {
        uint256 sumOfPercentage;
        uint256 numberOfStages = _releasePercentages.length;
        for (uint256 i; i < numberOfStages; i++) {
            sumOfPercentage += _releasePercentages[i];
        }

        require(sumOfPercentage == 100_00000, "ReleasePercentage are Not entered correctly!");

        if (numberOfPlatforms == 6) {
            platformFactoryState = State.Others;
        }
        _registerPlatform(name, contractAddress, admin, numberOfStages, _releasePercentages);

        emit NewPlatformAdded(name, contractAddress, admin);
    }

    /**
     * @dev Change a platform's stage to the next.
     * @param platformId Identifier of the platform.
     */
    function stageUpPlatform(uint256 platformId) external whenNotPaused {
        require(platformsInfo[platformId].admin != address(0), "Invalid Platform Id.");
        require(platformsInfo[platformId].admin == msg.sender, "The admin of the platform can staging up.");
        require(platformsInfo[platformId].platformActivated, "This Platofrm ID has been deacivated!");
        require(platformsInfo[platformId].stageActivated, "Allocation of this stage has not been transferred!");

        PlatformInfo storage platform = platformsInfo[platformId];
        platform.stageActivated = false;
        platform.currentStage++;
        emit PlatformsStageChanged(platform.name, platform.contractAddress, platform.currentStage);
    }

    /**
     * @dev Get the current stage of a platform.
     * @param platformId Identifier of the platform.
     * @return platformStage Current stage of the platform.
     */
    function getPlatformStage(uint256 platformId) external view returns (uint256 platformStage) {
        return (platformsInfo[platformId].currentStage);
    }

    /**
     * @dev Get the admin of a platform.
     * @param platformId Identifier of the platform.
     * @return paltformAdmin Admin address of the platform
     */
    function getPlatformAdmin(uint256 platformId) external view returns (address paltformAdmin) {
        return (platformsInfo[platformId].admin);
    }

    /**
     * @dev Decative a platform by allocator admin before last stage
     */
    function deactivePlatform(uint256 platformId) public restricted whenNotPaused {
        require(platformsInfo[platformId].admin != address(0), "Invalid Platform Id");
        require(platformsInfo[platformId].platformActivated, "This paltform already not activated!");
        require(
            platformsInfo[platformId].currentStage != platformsInfo[platformId].numberOfStages,
            "This is the last stage."
        );

        PlatformInfo storage platform = platformsInfo[platformId];
        platform.platformActivated = false;
        _checkDeactivation = true;
    }

    /**
     * @dev Acative a platform that deactivied by allocator admin before last stage
     */
    function activePlatform(uint256 platformId) public restricted whenNotPaused {
        require(platformsInfo[platformId].admin != address(0), "Invalid Platform Id");
        require(!platformsInfo[platformId].platformActivated, "This paltform already activated!");
        require(
            platformsInfo[platformId].currentStage != platformsInfo[platformId].numberOfStages,
            "This is the last stage."
        );

        PlatformInfo storage platform = platformsInfo[platformId];
        platform.platformActivated = true;
        _checkDeactivation = false;
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
     * @dev Internal function to register a platform.
     * @param name Name of the platform.
     * @param contractAddress Address of the platform's contract.
     * @param admin Admin address of the platform.
     * @param numberOfStages Number of stages for the platform.
     * @param releasePercentages Release percentages for each stage.
     */
    function _registerPlatform(
        string memory name,
        address contractAddress,
        address admin,
        uint256 numberOfStages,
        uint256[] memory releasePercentages
    ) private whenNotPaused {
        if (platformFactoryState == State.Allostasis) {
            uint256 totalFund = (375 * TOTAL_PLATFORM_ALLOCATION) / 6000;

            // adding new platform to the list
            platformsInfo[numberOfPlatforms] = PlatformInfo(
                name,
                contractAddress,
                admin,
                numberOfPlatforms,
                1,
                numberOfStages,
                0,
                totalFund,
                releasePercentages,
                false,
                true
            );
            numberOfPlatforms++;
        } else if (platformFactoryState == State.Others) {
            if ((numberOfPlatforms - 6) % 8 == 0) {
                halving++;
            }
            uint256 remainAmount = (625 * TOTAL_PLATFORM_ALLOCATION) / (2000 * halving);
            uint256 totalFund = remainAmount / 8;

            // adding new platform to the list
            platformsInfo[numberOfPlatforms] = PlatformInfo(
                name,
                contractAddress,
                admin,
                numberOfPlatforms,
                1,
                numberOfStages,
                0,
                totalFund,
                releasePercentages,
                false,
                true
            );
            numberOfPlatforms++;
        } else {
            revert("Registration Failed!");
        }
    }

    /**
     * @dev Internal function to check if a platform has reached the end of its stages.
     * @param platformId Identifier of the platform.
     */
    function _checkForEnd(uint256 platformId) private {
        PlatformInfo storage platform = platformsInfo[platformId];

        if ((platform.currentStage) == platform.numberOfStages) {
            platform.platformActivated = false;
        }
    }
}
