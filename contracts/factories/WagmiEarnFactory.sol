// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "../interfaces/ISubFactory.sol";
import "../strategies/StrategyWagmiEarn.sol";
import "./StrategyFactory.sol";
/**
 * Project data: (address masterchef, address rewardToken)
 * Strategy data: (uint256 pid)
 */
contract WagmiEarnFactory is ISubFactory {
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
        (IWagmiEarn masterchef, IERC20 rewardToken) = abi.decode(projectData, (IWagmiEarn, IERC20));
        (uint256 pid, address[] memory route) = abi.decode(strategyData, (uint256, address[]));
        // validate underlying masterchef
        _validateMasterchef(masterchef, underlyingToken, pid);
        
        // initialize strategy
        StrategyWagmiEarn strategy = new StrategyWagmiEarn();
        strategy.initialize(vaultChef, zap, underlyingToken, rewardToken, masterchef, pid);
        
        // set swap route
        if (route.length > 0) {
            strategyFactory.setRoute(route);
        }
        return strategy;
    }

    function _validateMasterchef(IWagmiEarn masterchef, IERC20 underlyingToken, uint256 pid) internal view {
        try  masterchef.poolLength() returns (
            uint256 length
        ) {
            require(pid < length, "pool nonexistent");
        } catch {
            revert("!incorrect poolLength");
        }

        try  masterchef.poolInfo(pid) returns (address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accWagmiPerShare, uint256 lpSupply) {
            require(lpToken == address(underlyingToken), "!underlying");
            allocPoint;lastRewardBlock;accWagmiPerShare;lpSupply;//sh
        } catch {
            revert("!incorrect poolInfo");
        }
        try  masterchef.userInfo(pid, address(this)) returns (uint256 amount, uint256 rewardDebt, uint256 stored) {
            amount;rewardDebt;stored;//sh
        } catch {
            revert("!incorrect userInfo");
        }
    }
}