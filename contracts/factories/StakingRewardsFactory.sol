// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IStakingRewards.sol";
import "../interfaces/ISubFactory.sol";
import "../strategies/StrategyStakingRewards.sol";
/**
 * Project data: ()
 * Strategy data: (address stakingContract)
 */
contract StakingRewardsFactory is ISubFactory {
    address public immutable strategyFactory;
    IZap public zap;

    constructor(address _strategyFactory, IZap _zap) {
        strategyFactory = _strategyFactory;
        zap = _zap;
    }

    function deployStrategy(
        IVaultChef vaultChef,
        IERC20 underlyingToken,
        bytes calldata projectData,
        bytes calldata strategyData
    ) external override returns (IStrategy) {
        require(msg.sender == strategyFactory);
        (IERC20 rewardToken) = abi.decode(projectData, (IERC20));
        (IStakingRewards stakingContract) = abi.decode(strategyData, (IStakingRewards));

        _validateUnderlying(stakingContract, underlyingToken, rewardToken);
        
        StrategyStakingRewards strategy = new StrategyStakingRewards();
        strategy.initialize(vaultChef, zap, underlyingToken, rewardToken, stakingContract);

        return strategy;
    }

    function _validateUnderlying(IStakingRewards staking, IERC20 underlyingToken, IERC20 rewardToken) internal view {
        require(address(staking.stakingToken()) == address(underlyingToken), "!wrong underlying");
        require(address(staking.rewardsToken()) == address(rewardToken), "!wrong underlying");
        try staking.balanceOf(address(this)) returns (uint256 bal) {
            bal;//sh
        } catch {
            revert("!no balanceOf method");
        }
    }
}