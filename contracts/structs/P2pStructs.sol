// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../feeDistributor/IFeeDistributor.sol";

/// @dev 256 bit struct
/// @member basisPoints basis points (percent * 100) of EL rewards that should go to the recipient
/// @member recipient address of the recipient
struct FeeRecipient {
    uint96 basisPoints;
    address payable recipient;
}

/// @dev 256 bit struct
/// @member depositedCount the number of deposited validators
/// @member exitedCount the number of validators requested to exit
/// @member collateralReturnedValue amount of ETH returned to the client to cover the collaterals
/// @member cooldownUntil timestamp after which it will be possible to withdraw ignoring the client's revert on ETH receive
struct ValidatorData {
    uint32 depositedCount;
    uint32 exitedCount;
    uint112 collateralReturnedValue;
    uint80 cooldownUntil;
}

/// @dev status of the client deposit
/// @member None default status indicating that no ETH is waiting to be forwarded to Beacon DepositContract
/// @member EthAdded client added ETH
/// @member BeaconDepositInProgress P2P has forwarded some (but not all) ETH to Beacon DepositContract
/// If all ETH has been forwarded, the status will be None.
/// @member ServiceRejected P2P has rejected the service for a given FeeDistributor instance
// The client can get a refund immediately.
enum ClientDepositStatus {
    None,
    EthAdded,
    BeaconDepositInProgress,
    ServiceRejected
}

/// @dev 256 bit struct
/// @member amount ETH in wei to be used for an ETH2 deposit corresponding to a particular FeeDistributor instance
/// @member expiration block timestamp after which the client will be able to get a refund
/// @member status deposit status
/// @member ethAmountPerValidatorInWei amount of ETH to deposit per 1 validator (should be >= 32 and <= 2048)
struct ClientDeposit {
    uint112 amount;
    uint40 expiration;
    ClientDepositStatus status;
    uint96 ethAmountPerValidatorInWei;
}

/// @dev 256 bit struct
/// @member clientAmount ETH in wei to be sent to the client
/// @member serviceAmount ETH in wei to be sent to the service
/// @member referrerAmount ETH in wei to be sent to the referrer
struct Withdrawal {
    uint80 clientAmount;
    uint80 serviceAmount;
    uint80 referrerAmount;
}
