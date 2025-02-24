// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITokenAllocator.sol";

/**
 * @title StockSlipsAllo
 * @dev ERC721 token representing staked Allo tokens with role-based allocation.
 */
contract StockSlipsAllo is ERC721, ERC721Pausable, AccessManaged {
    
    uint256 private _nextTokenId;
    ITokenAllocator public tokenAllocator;
    IERC20 public Allo;

    /**
     * @dev Emitted when a new ssAllo token is minted.
     * @param stakerAddr The address of the staker.
     * @param tokenId The ID of the newly minted token.
     * @param role The role associated with the token.
     * @param stage The stage in which the token was minted.
     * @param lockedAmount The amount of Allo tokens locked in this NFT.
     */
    event Mint(address stakerAddr, uint256 tokenId, Recipients role, int8 stage, uint256 lockedAmount);

    /**
     * @dev Emitted when an ssAllo token is burned.
     * @param stakerAddr The address of the staker.
     * @param tokenId The ID of the burned token.
     * @param unlockAmount The amount of Allo tokens unlocked.
     */
    event Burn(address stakerAddr, uint256 tokenId, uint256 unlockAmount);

    mapping(uint256 => NFTsData) public nftsData; 
    mapping(bytes32 => RecipientsAssets) public recipientsAssets; 

    struct NFTsData {
        address stakerAddr;
        Recipients role;
        int8 stage;
    }

    struct RecipientsAssets {
        uint256 nftId;
        uint256 lockedAmount;
    }

    /**
     * @dev Enumeration representing different roles eligible for staking and receiving NFTs.
     */
    enum Recipients {
        user,        
        creators,    
        contentNodes,
        infraNodes,  
        devTeam,     
        stakers      
    }

    /**
     * @dev Initializes the contract by setting a name, symbol, initial authority, token allocator, and Allo token address.
     * @param initialAuthority The address of the initial authority for managing access.
     * @param tokenAllocatorAddr The address of the token allocator contract.
     * @param AlloAddr The address of the Allo ERC20 token contract.
     */
    constructor(address initialAuthority, address tokenAllocatorAddr, address AlloAddr) 
        ERC721("StockSlipsAllo", "ssAllo") 
        AccessManaged(initialAuthority) 
    {
        Allo = IERC20(AlloAddr);
        tokenAllocator = ITokenAllocator(tokenAllocatorAddr);
    }

    /**
     * @dev Mints a new ssAllo ERC721 token for the staker by locking their Allo ERC20 tokens.
     * Each role in each stage gets one ssAllo NFT and all the locked amount is assigned to that NFT.
     * @param _stakerAddr The address of the staker.
     * @param _role The role associated with the NFT.
     * @param _amount The amount of Allo tokens to be locked.
     */
    function stakeAllo(address _stakerAddr, Recipients _role, uint256 _amount) external {
        require(Allo.balanceOf(msg.sender) >= _amount, "Insufficient balance!");
        require(Allo.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance!");
        require(_amount >= 1000_000000000000000000, "At least 1000 Allo token should be staked!");
        
        Allo.transferFrom(msg.sender, address(this), _amount);
        Recipients role = (msg.sender == _stakerAddr) ? Recipients.stakers : _role; 
        bytes32 _signiture = dataSigning(tokenAllocator.currentStage(), role, _stakerAddr);

        RecipientsAssets storage staker = recipientsAssets[_signiture];

        if (staker.lockedAmount != 0) {
            staker.lockedAmount += _amount;
        } else {
            uint256 tokenId = _nextTokenId++;
            _safeMint(_stakerAddr, tokenId);
            recipientsAssets[_signiture] = RecipientsAssets(tokenId, _amount);
            
            nftsData[tokenId] = NFTsData(_stakerAddr, role, tokenAllocator.currentStage());
            emit Mint(_stakerAddr, tokenId, role, tokenAllocator.currentStage(), _amount);
        }
    }

    /**
     * @dev Burns an ssAllo token and releases the locked Allo tokens to the token owner.
     * The owner can only burn the token after a specified number of stages.
     * @param _tokenId The ID of the token to be burned.
     */
    function burnSsAllo(uint256 _tokenId) external {
        require(_exists(_tokenId),"NFT ID does not exist!");
        int8 currentStage = tokenAllocator.currentStage();
        require(ownerOf(_tokenId) == msg.sender, "Only the owner of the token can burn it");
        NFTsData memory userData2 = nftsData[_tokenId];
        require(currentStage >= userData2.stage + 2, "NFTs can be burned 2 steps after being minted!");
        _burn(_tokenId);
        bytes32 _signiture = keccak256(abi.encodePacked(userData2.stage, userData2.role, userData2.stakerAddr));
        uint256 unlockAmount = recipientsAssets[_signiture].lockedAmount;
        delete recipientsAssets[_signiture];
        delete nftsData[_tokenId];

        Allo.transfer(msg.sender, unlockAmount);
        emit Burn(msg.sender, _tokenId, unlockAmount);
    }

    /**
     * @dev Pauses all token transfers.
     * Can only be called by an account with the `restricted` role.
     */
    function pause() public restricted {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     * Can only be called by an account with the `restricted` role.
     */
    function unpause() public restricted {
        _unpause();
    }

    /**
     * @dev Generates a unique signature based on stage, role, and staker address.
     * @param _stage The current stage of the allocation.
     * @param _role The role associated with the NFT.   
     * @param _stakerAddr The address of the staker.
     * @return A bytes32 signature.
     */
    function dataSigning(int8 _stage, Recipients _role, address _stakerAddr) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_stage, _role, _stakerAddr));
    }

    /**
     * @dev Returns the asset data for a specific staker address.
     * @param _stakerAddr The address of the staker.
     * @return The number of NFTs owned by the staker and a 2D array containing token IDs, stages, role and locked amounts.
     */
    function getAssetsData(address _stakerAddr) public view returns (uint256, uint256[][] memory) {
        uint256 numNFTs = balanceOf(_stakerAddr);
        uint256[][] memory assetsData = new uint256[][](numNFTs);
        
        uint256 j;
        for (uint256 i; i <= _nextTokenId; i++) {
            // Check if token exists by verifying if the owner is a non-zero address.
            if (_exists(i) && ownerOf(i) == _stakerAddr) {
                assetsData[j] = new uint256[](4);
                assetsData[j][0] = i;
                assetsData[j][1] = uint256(uint8(nftsData[i].stage));
                assetsData[j][2] = uint256(uint8(nftsData[i].role));
                bytes32 signature = keccak256(abi.encodePacked(nftsData[i].stage, nftsData[i].role, nftsData[i].stakerAddr));
                assetsData[j][3] = recipientsAssets[signature].lockedAmount;
                j++;
            } 
        }
        return (numNFTs, assetsData);
    }

    /**
    * @notice Checks if a token with the given ID exists.
    * @dev This function determines the existence of a token by checking if it has an owner.
    * @param tokenId The unique identifier of the token to check.
    * @return bool Returns true if the token exists, i.e., it has a non-zero address as its owner, otherwise false.
    */
    function _exists(uint256 tokenId) internal view returns (bool) {
    return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Updates the token transfer logic.
     * This function overrides the _update function in ERC721 and ERC721Pausable.
     * @param to The address receiving the token.
     * @param tokenId The ID of the token being transferred.
     * @param auth Authorization data for the transfer.
     * @return The address that received the token.
     */
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Pausable) returns (address) {
        return super._update(to, tokenId, auth);
    }
}