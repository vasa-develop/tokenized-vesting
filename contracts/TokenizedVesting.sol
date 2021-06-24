// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProofUpgradeable {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}


contract TokenizedVesting is ERC721("TokenizedVesting", "TVEST") {
    // Use merkle tree to initialize the share values. Whenever a user calls the contract for
    // the first time, they also mint a non-fungible position, where the tokenId is the index
    // of the leaf in the merkletree.

    // Users can claim their vested share of ERC20 tokens (contract calculates and transfers ERC20s accordingly)
    // at any point in time
    
    // Each vesting schedule is represented as a non-fungible position.
    
    // When a user transfers his/her vesting position, the contract internally calls claim
    // to send all vested ERC20s to the sender address. The reciever of the vesting position
    // will then start earning the vested tokens.

    // NOTE: This contract does NOT have to transfer the ERC20 tokens. You could have an alternative
    // mechanism where you can give this contract access to mint pro-rata amount of ERC20 tokens to the user.
    
    // NOTE: You can also have more complex systems with more advanced vesting mechanics (different vesting durations, cliffs)
    // Check this implementation for a dynamic vesting escrow: https://github.com/vasa-develop/dynamic-vesting-escrow
    // The linked implementation only serves as an example of an advanced vesting mechanics, but it does NOT demonstrate
    // tokenized vesting.

    struct TokenDetails {
        uint256 share;
        uint256 lastClaimedAt;
    }

    mapping (uint256 => TokenDetails) public tokenDetails;
    bytes32 public immutable merkleRoot;
    uint256 public immutable TOTAL_VESTING_DURATION; // in seconds
    uint256 public immutable VESTING_END_TIME; // in seconds
    address public immutable rewardToken;

    event Claimed(uint256 index, address account, uint256 amount);

    constructor(bytes32 _merkleRoot, uint256 _totalVestingDuration, address _rewardToken) {
        merkleRoot = _merkleRoot;
        TOTAL_VESTING_DURATION = _totalVestingDuration;
        VESTING_END_TIME = block.timestamp+_totalVestingDuration;
        rewardToken = _rewardToken;
    }

    // NOTE: You only need to pass the account, shares, and merkleProof for the first time a specific user interacts
    // with the contract.
    function claim(address account, uint256 index, uint256 share, bytes32[] calldata merkleProof) external {
        // get the position owner of the index
        _assertPositionOwner(account, index, share, merkleProof);
        // call _claim()
        _claim(index);
    }

    function _assertPositionOwner(address account, uint256 index, uint256 share, bytes32[] calldata merkleProof) internal {
        // index acts as tokenId. Check if the tokenId is already minted or not.
        // if position has no owner, then verify proofs and mint a position
        if(!_exists(index)) {
            // verify the merkle proof.
            bytes32 node = keccak256(abi.encodePacked(index, account, share));
            require(
                MerkleProofUpgradeable.verify(merkleProof, merkleRoot, node),
                "Invalid proof."
            );
            // mint vesting position 
            _mint(account, index);
            // set token details
            tokenDetails[index] = TokenDetails(share, block.timestamp);
        }
    }

    function getClaimableAmount(uint256 index) public view returns (uint256) {
        return block.timestamp >= VESTING_END_TIME
            ? (tokenDetails[index].share*(VESTING_END_TIME-tokenDetails[index].lastClaimedAt))/TOTAL_VESTING_DURATION
            : (tokenDetails[index].share*(block.timestamp-tokenDetails[index].lastClaimedAt))/TOTAL_VESTING_DURATION;
    }

    function test(uint256 index) public view returns (uint256,uint256,uint256) {
        return (
            tokenDetails[index].share,
            block.timestamp-tokenDetails[index].lastClaimedAt,
            (tokenDetails[index].share*(block.timestamp-tokenDetails[index].lastClaimedAt))/TOTAL_VESTING_DURATION
        );    
    }

    function _claim(uint256 index) internal returns(uint256 rewardAmount) {
        // calculate the rewards to be claimed
        rewardAmount = getClaimableAmount(index);
        // set the lastClaimedAt for the token
        tokenDetails[index].lastClaimedAt = block.timestamp;
        // transfer the rewards
        IERC20(rewardToken).transfer(ownerOf(index), rewardAmount);
        // emit event
        Claimed(index, ownerOf(index), rewardAmount);
    }
    
    function _transfer(address from, address to, uint256 tokenId) internal override virtual {
        // first claim all the vested ERC20 tokens
        _claim(tokenId);
        // transfer the vesting position 
        super._transfer(from, to, tokenId);
    }
}