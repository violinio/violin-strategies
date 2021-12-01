// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "../interfaces/ISubFactory.sol";
import "../strategies/StrategyFuseFiStaking.sol";
import "./StrategyFactory.sol";
/**
 * Project data: (address masterchef, address rewardToken)
 * Strategy data: (uint256 pid)
 */
contract FuseFiStakingFactory is ISubFactory {
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
        (IERC20 rewardToken) = abi.decode(projectData, (IERC20));
        (IFuseFiMultiRewards staking, address[] memory route) = abi.decode(strategyData, (IFuseFiMultiRewards, address[]));
        // validate underlying masterchef
        _validateStaking(staking, underlyingToken, rewardToken);
        
        // initialize strategy
        StrategyFuseFiStaking strategy = new StrategyFuseFiStaking();
        strategy.initialize(vaultChef, zap, underlyingToken, rewardToken, staking);
        
        // set swap route
        if (route.length > 0) {
            strategyFactory.setRoute(route);
        }
        return strategy;
    }

    function _validateStaking(IFuseFiMultiRewards staking, IERC20 underlyingToken, IERC20 rewardToken) internal view {
        try  staking.stakingToken() returns (address stakeToken) {
            require(stakeToken == address(underlyingToken), "!underlyingToken");
        } catch {
            revert("!incorrect getStakeToken");
        }
        try  staking.rewardTokens(0) returns (address _rewardToken) {
            require(_rewardToken == address(rewardToken), "!rewardToken");
        } catch {
            revert("!incorrect getRewardToken");
        }
        try  staking.balanceOf(address(this)) returns (uint256 amount) {
            amount;
        } catch {
            revert("!incorrect userInfo");
        }
    }
}