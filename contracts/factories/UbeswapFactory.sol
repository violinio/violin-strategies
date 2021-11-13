// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IMoolaStakingRewards.sol";
import "../interfaces/ISubFactory.sol";
import "../strategies/StrategyUbeswap.sol";
/**
 * Project data: ()
 * Strategy data: (address stakingContract)
 */
contract UbeSwapFactory is ISubFactory {
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
        //() = abi.decode(projectData, ());
        (address stakingContract, IERC20[] memory rewardTokens) = abi.decode(strategyData, (address, IERC20[]));

        IMoolaStakingRewards staking = IMoolaStakingRewards(stakingContract);
        _validateUnderlying(staking);
        
        StrategyUbeswap strategy = new StrategyUbeswap();
        strategy.initialize(vaultChef, zap, underlyingToken, rewardTokens, staking);

        return strategy;
    }

    function _validateUnderlying(IMoolaStakingRewards staking) internal view {

    }
}