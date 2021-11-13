// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;
import "../interfaces/IStrategy.sol";
import "../interfaces/IVaultChef.sol";

interface ISubFactory {
    function deployStrategy(
        IVaultChef vaultChef,
        IERC20 underlyingToken,
        bytes calldata projectData,
        bytes calldata strategyData
    ) external returns (IStrategy);
}
