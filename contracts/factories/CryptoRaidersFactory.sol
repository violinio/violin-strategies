// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "../interfaces/ISubFactory.sol";
import "../strategies/StrategyCryptoRaiders.sol";
import "./StrategyFactory.sol";
/**
 * Project data: (address masterchef, address rewardToken)
 * Strategy data: (uint256 pid)
 */
contract CryptoRaidersFactory is ISubFactory {
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
        (ICryptoRaidersStaking staking) = abi.decode(strategyData, (ICryptoRaidersStaking));
        // validate underlying masterchef
        _validateStaking(staking, underlyingToken, rewardToken);
        
        // initialize strategy
        StrategyCryptoRaiders strategy = new StrategyCryptoRaiders();
        strategy.initialize(vaultChef, zap, underlyingToken, IERC20(rewardToken), staking);
        
        return strategy;
    }

    function _validateStaking(ICryptoRaidersStaking staking, IERC20 underlyingToken, IERC20 rewardsToken) internal view {
        try  staking.showRewardToken() returns (address _rewardsToken) {
            require(address(rewardsToken) == _rewardsToken, "!incorrect rewardsToken");
        } catch {
            revert("!no rewardsToken");
        }
        try  staking.showStakingToken() returns (address _stakingToken) {
            require(address(underlyingToken) == _stakingToken, "!incorrect stakingToken");
        } catch {
            revert("!no stakingToken");
        }

        try staking.addressStakedBalance(address(this)) returns (uint256 amount) {
            amount;//sh
        } catch {
            revert("!incorrect balance function");
        }
    }
}