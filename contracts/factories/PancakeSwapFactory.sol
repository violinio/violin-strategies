// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IPancakeSwapMC.sol";
import "../interfaces/ISubFactory.sol";
import "../strategies/StrategyPancakeSwap.sol";
import "./StrategyFactory.sol";
/**
 * Project data: (address masterchef, address rewardToken)
 * Strategy data: (uint256 pid)
 */
contract PancakeSwapFactory is ISubFactory {
    StrategyFactory public immutable strategyFactory;
    IZap public zap;

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
        (address masterchefAddress, address rewardToken) = abi.decode(projectData, (address, address));
        (uint256 pid, address[] memory route) = abi.decode(strategyData, (uint256, address[]));
        // validate underlying masterchef
        IPancakeSwapMC masterchef = IPancakeSwapMC(masterchefAddress);
        _validateMasterchef(masterchef, underlyingToken, pid);
        
        // initialize strategy
        StrategyPancakeSwap strategy = new StrategyPancakeSwap();
        strategy.initialize(vaultChef, zap, underlyingToken, IERC20(rewardToken), masterchef, pid);
        
        // set swap route
        if (route.length > 0) {
            strategyFactory.setRoute(route);
        }
        return strategy;
    }

    function _validateMasterchef(IPancakeSwapMC masterchef, IERC20 underlyingToken, uint256 pid) internal view {
        try  masterchef.poolLength() returns (
            uint256 length
        ) {
            require(pid < length, "pool nonexistent");
        } catch {
            revert("!incorrect poolLength");
        }
        try  masterchef.userInfo(pid, address(this)) returns (uint256 amount, uint256 rewardDebt) {
            amount;rewardDebt;//sh
        } catch {
            revert("!incorrect userInfo");
        }
    }
}