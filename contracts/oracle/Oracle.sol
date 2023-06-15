// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../assetRecovering/OwnableAssetRecoverer.sol";
import "../access/OwnableWithOperator.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./IOracle.sol";

/**
* @notice Invalid Proof
*/
error Oracle__InvalidProof();

/**
* @title Oracle stores the Merkle root updated regularly
* @dev Leaves are hashes of:
* - feeDistributorInstance address
* - sum of CL rewards earned by all validators of feeDistributorInstance)
*/
contract Oracle is OwnableAssetRecoverer, OwnableWithOperator, ERC165, IOracle {
    bytes32 private s_root;

    /**
    * @notice Set a new oracle report (Merkle root)
    * @param _root Merkle root
    */
    function report(bytes32 _root) external onlyOperatorOrOwner {
        s_root = _root;

        emit Oracle__Reported(_root);
    }

    /**
    * @notice Verify Merkle proof (that the leaf belongs to the tree)
    * @param _proof Merkle proof (the leaf's sibling, and each non-leaf hash that could not otherwise be calculated without additional leaf nodes)
    * @param _feeDistributorInstance feeDistributor instance address
    * @param _amountInGwei total CL rewards earned by all validators in GWei (see _validatorCount)
    */
    function verify(
        bytes32[] calldata _proof,
        address _feeDistributorInstance,
        uint256 _amountInGwei
    ) external view {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_feeDistributorInstance, _amountInGwei))));

        if (!MerkleProof.verify(_proof, s_root, leaf)) {
            revert Oracle__InvalidProof();
        }
    }

    /**
    * @dev See {IERC165-supportsInterface}.
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IOracle).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
    * @dev Returns the address of the current owner.
     */
    function owner() public view override(Ownable, OwnableBase, IOwnable) returns (address) {
        return super.owner();
    }
}
