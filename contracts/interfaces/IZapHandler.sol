// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice The IZap interface allows contracts to swap a token for another token without having to directly interact with verbose AMMs directly.
/// @notice It furthermore allows to zap to and from an LP pair within a single transaction.
interface IZapHandler {
    struct Factory {
        /// @dev The address of the factory.
        address factory;
        /// @dev The fee nominator of the AMM, usually set to 997 for a 0.3% fee.
        uint32 amountsOutNominator;
        /// @dev The fee denominator of the AMM, usually set to 1000.
        uint32 amountsOutDenominator;
    }

    function setFactory(
        address factory,
        uint32 amountsOutNominator,
        uint32 amountsOutDenominator
    ) external;

    function setRoute(
        IERC20 from,
        IERC20 to,
        address[] memory inputRoute
    ) external;
    function factories(address factoryAddress) external view returns (Factory memory);

    function routeLength(IERC20 token0, IERC20 token1) external view returns (uint256);

    function owner() external view returns (address);
}