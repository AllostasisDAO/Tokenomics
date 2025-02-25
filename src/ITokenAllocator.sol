// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ITokenAllocator
 * @dev Interface for the TokenAllocator smart contract responsible for allocating and distributing Allo tokens.
 * Implements the Pausable, AccessManaged, and ReentrancyGuard interfaces.
 */
interface ITokenAllocator {
    /// @notice Returns the last stage for which tokens were minted.
    /// @return The last minted stage as an int8.
    function lastMintedStage() external view returns (int8);

    /// @notice Returns the current distribution stage.
    /// @return The current stage as an int8.
    function currentStage() external view returns (int8);

    /// @notice Returns the address designated for the Content platform.
    /// @return The address of the Content platform.
    function contentAddress() external view returns (address);

    /// @notice Returns the address designated for the development infrastructure.
    /// @return The address of the development infrastructure.
    function devInfraAddress() external view returns (address);

    /// @notice Returns the address of the Treasury.
    /// @return The address of the Treasury.
    function treasuryAddress() external view returns (address);
}
