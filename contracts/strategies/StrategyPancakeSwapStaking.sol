// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IPancakeSwapMC.sol";
import "./BaseStrategy.sol";

contract StrategyPancakeSwapStaking is BaseStrategy {
    IPancakeSwapMC public masterchef;

    address deployer;

    constructor() {
        deployer = msg.sender;
    }

    function initialize(
        IVaultChef _vaultchef,
        IZap _zap,
        IERC20 _underlyingToken,
        IERC20 _rewardToken,
        IPancakeSwapMC _masterchef
    ) external initializer {
        require(msg.sender == deployer);
        _initializeBase(_vaultchef, _zap, _underlyingToken, _rewardToken);

        masterchef = _masterchef;
    }

    function _panic() internal override {
        masterchef.emergencyWithdraw(0);
    }

    function _harvest() internal override {
        masterchef.enterStaking(0);
    }

    function _deposit(uint256 amount) internal override {
        underlyingToken.approve(address(masterchef), amount);
        masterchef.enterStaking(amount);
    }

    function _withdraw(uint256 amount) internal override {
        masterchef.leaveStaking(amount);
    }

    function _totalStaked() internal view override returns (uint256) {
        (uint256 amount, ) = masterchef.userInfo(0, address(this));
        return amount;
    }
}