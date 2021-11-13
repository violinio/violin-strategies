// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IMoolaStakingRewards.sol";
import "./BaseStrategyMulti.sol";

contract StrategyUbeswap is BaseStrategyMulti {
    IMoolaStakingRewards public staking;
    uint256 public pid;

    address deployer;

    constructor() {
        deployer = msg.sender;
    }

    function initialize(
        IVaultChef _vaultchef,
        IZap _zap,
        IERC20 _underlyingToken,
        IERC20[] calldata _rewardTokens,
        IMoolaStakingRewards _staking
    ) external initializer {
        require(msg.sender == deployer);
        _initializeBase(_vaultchef, _zap, _underlyingToken, _rewardTokens);

        staking = _staking;
    }

    function _panic() internal override {
        // Synthetix has no safe withdraw function, exit is less secure as it still attempts a rewards transfer.
        staking.withdraw(staking.balanceOf(address(this)));
    }

    function _harvest() internal override {
        staking.getReward();
    }

    function _deposit(uint256 amount) internal override {
        staking.stake(amount);
    }

    function _withdraw(uint256 amount) internal override {
        staking.withdraw(amount);
    }

    function _totalStaked() internal view override returns (uint256) {
        return staking.balanceOf(address(this));
    }
}
