// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/ISushiMiniChefV2.sol";
import "../interfaces/ISubFactory.sol";
import "../strategies/StrategySushiMiniChefV2.sol";
import "./StrategyFactory.sol";
/**
 * Project data: (address masterchef, address rewardToken)
 * Strategy data: (uint256 pid)
 */
contract SushiMiniChefV2Factory is ISubFactory {
    StrategyFactory public immutable strategyFactory;
    IZap public immutable zap;

    constructor(StrategyFactory _strategyFactory, IZap _zap) {
        strategyFactory = _strategyFactory;
        zap = _zap;
    }

    function deployStrategy(
        IVaultChef vaultChef,
        IERC20 underlyingToken,
        bytes calldata projectData,
        bytes calldata strategyData
    ) external override returns (IStrategy) {
        require(msg.sender == address(strategyFactory));
        (address minichefAddress, IERC20[] memory rewardTokens) = abi.decode(projectData, (address, IERC20[]));
        (uint256 pid, address[] memory route) = abi.decode(strategyData, (uint256, address[]));
        // validate underlying masterchef
        ISushiMiniChefV2 minichef = ISushiMiniChefV2(minichefAddress);
        _validateMasterchef(minichef, underlyingToken, pid);
        
        // initialize strategy
        StrategyPancakeSwap strategy = new StrategyPancakeSwap();
        strategy.initialize(vaultChef, zap, underlyingToken, rewardTokens, minichef, pid);
        
        // set swap route
        if (route.length > 0) {
            strategyFactory.setRoute(route);
        }
        return strategy;
    }

    function _validateMasterchef(ISushiMiniChefV2 minichef, IERC20 underlyingToken, uint256 pid) internal view {
        try  minichef.poolLength() returns (
            uint256 length
        ) {
            require(pid < length, "pool nonexistent");
        } catch {
            revert("!incorrect poolLength");
        }
        try  minichef.userInfo(pid, address(this)) returns (uint256 amount, int256 rewardDebt) {
            amount;rewardDebt;//sh
        } catch {
            revert("!incorrect userInfo");
        }
    }
}