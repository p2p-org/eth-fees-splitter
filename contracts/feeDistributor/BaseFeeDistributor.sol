// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../assetRecovering/OwnableTokenRecoverer.sol";
import "../access/OwnableWithOperator.sol";
import "./IFeeDistributor.sol";
import "./FeeDistributorErrors.sol";
import "../structs/P2pStructs.sol";
import "../lib/P2pAddressLib.sol";
import "./Erc4337Account.sol";

/// @title Common logic for all FeeDistributor types
abstract contract BaseFeeDistributor is
    Erc4337Account,
    OwnableTokenRecoverer,
    OwnableWithOperator,
    ReentrancyGuard,
    ERC165,
    IFeeDistributor
{
    /// @notice FeeDistributorFactory address
    IFeeDistributorFactory internal immutable i_factory;

    /// @notice P2P fee recipient address
    address payable internal immutable i_service;

    /// @notice Client rewards recipient address and basis points
    FeeRecipient internal s_clientConfig;

    /// @notice Referrer rewards recipient address and basis points
    FeeRecipient internal s_referrerConfig;

    /// @notice If caller not client, revert
    modifier onlyClient() {
        address clientAddress = s_clientConfig.recipient;

        if (clientAddress != msg.sender) {
            revert FeeDistributor__CallerNotClient(msg.sender, clientAddress);
        }
        _;
    }

    /// @notice If caller not factory, revert
    modifier onlyFactory() {
        if (msg.sender != address(i_factory)) {
            revert FeeDistributor__NotFactoryCalled(msg.sender, i_factory);
        }
        _;
    }

    /// @dev Set values that are constant, common for all the clients, known at the initial deploy time.
    /// @param _factory address of FeeDistributorFactory
    /// @param _service address of the service (P2P) fee recipient
    constructor(address _factory, address payable _service) {
        if (
            !ERC165Checker.supportsInterface(
                _factory,
                type(IFeeDistributorFactory).interfaceId
            )
        ) {
            revert FeeDistributor__NotFactory(_factory);
        }
        if (_service == address(0)) {
            revert FeeDistributor__ZeroAddressService();
        }

        i_factory = IFeeDistributorFactory(_factory);
        i_service = _service;

        bool serviceCanReceiveEther = P2pAddressLib._sendValue(_service, 0);
        if (!serviceCanReceiveEther) {
            revert FeeDistributor__ServiceCannotReceiveEther(_service);
        }
    }

    /// @inheritdoc IFeeDistributor
    function initialize(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) public virtual onlyFactory {
        if (_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ZeroAddressClient();
        }
        if (_clientConfig.recipient == i_service) {
            revert FeeDistributor__ClientAddressEqualsService(
                _clientConfig.recipient
            );
        }
        if (s_clientConfig.recipient != address(0)) {
            revert FeeDistributor__ClientAlreadySet(s_clientConfig.recipient);
        }

        if (_referrerConfig.recipient != address(0)) {
            // if there is a referrer
            if (_referrerConfig.recipient == i_service) {
                revert FeeDistributor__ReferrerAddressEqualsService(
                    _referrerConfig.recipient
                );
            }
            if (_referrerConfig.recipient == _clientConfig.recipient) {
                revert FeeDistributor__ReferrerAddressEqualsClient(
                    _referrerConfig.recipient
                );
            }

            // set referrer config
            s_referrerConfig = _referrerConfig;
        }

        // set client config
        s_clientConfig = _clientConfig;

        emit FeeDistributor__Initialized(
            _clientConfig.recipient,
            _clientConfig.basisPoints,
            _referrerConfig.recipient,
            _referrerConfig.basisPoints
        );

        bool clientCanReceiveEther = P2pAddressLib._sendValue(
            _clientConfig.recipient,
            0
        );
        if (!clientCanReceiveEther) {
            revert FeeDistributor__ClientCannotReceiveEther(
                _clientConfig.recipient
            );
        }
        if (_referrerConfig.recipient != address(0)) {
            // if there is a referrer
            bool referrerCanReceiveEther = P2pAddressLib._sendValue(
                _referrerConfig.recipient,
                0
            );
            if (!referrerCanReceiveEther) {
                revert FeeDistributor__ReferrerCannotReceiveEther(
                    _referrerConfig.recipient
                );
            }
        }
    }

    /// @notice Accept ether from transactions
    receive() external payable {
        // only accept ether in an instance, not in a template
        if (s_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }
    }

    /// @inheritdoc IFeeDistributor
    function factory() external view returns (address) {
        return address(i_factory);
    }

    /// @inheritdoc IFeeDistributor
    function service() external view returns (address) {
        return i_service;
    }

    /// @inheritdoc IFeeDistributor
    function client()
        public
        view
        override(Erc4337Account, IFeeDistributor)
        returns (address)
    {
        return s_clientConfig.recipient;
    }

    /// @inheritdoc IFeeDistributor
    function clientBasisPoints() external view returns (uint256) {
        return s_clientConfig.basisPoints;
    }

    /// @inheritdoc IFeeDistributor
    function referrer() external view returns (address) {
        return s_referrerConfig.recipient;
    }

    /// @inheritdoc IFeeDistributor
    function referrerBasisPoints() external view returns (uint256) {
        return s_referrerConfig.basisPoints;
    }

    /// @inheritdoc ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IFeeDistributor).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IOwnable
    function owner()
        public
        view
        override(Erc4337Account, OwnableBase, Ownable, IOwnable)
        returns (address)
    {
        return i_factory.owner();
    }

    /// @inheritdoc IOwnableWithOperator
    function operator()
        public
        view
        override(Erc4337Account, OwnableWithOperator)
        returns (address)
    {
        return super.operator();
    }
}
