// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IFuseFiStaking.sol";
import "./BaseStrategy.sol";

contract StrategyFuseFiStaking is BaseStrategy {
    IFuseFiMultiRewards public staking;
    uint256 public pid;

    address deployer;

    constructor() {
        deployer = msg.sender;
    }

    function initialize(
        IVaultChef _vaultchef,
        IZap _zap,
        IERC20 _underlyingToken,
        IERC20 _rewardToken,
        IFuseFiMultiRewards _staking
    ) external initializer {
        require(msg.sender == deployer);
        _initializeBase(_vaultchef, _zap, _underlyingToken, _rewardToken);

        staking = _staking;
    }

    function _panic() internal override {
        staking.withdraw(_totalStaked());
    }

    function _harvest() internal override {
        staking.getReward();
    }

    function _deposit(uint256 amount) internal override {
        underlyingToken.approve(address(staking), amount);
        staking.stake(amount);
    }

    function _withdraw(uint256 amount) internal override {
        staking.withdraw(amount);
    }

    function _totalStaked() internal view override returns (uint256) {
        return staking.balanceOf(address(this));
    }
}