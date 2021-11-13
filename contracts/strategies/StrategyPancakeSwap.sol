// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IPancakeSwapMC.sol";
import "./BaseStrategy.sol";

contract StrategyPancakeSwap is BaseStrategy {
    IPancakeSwapMC public masterchef;
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
        IPancakeSwapMC _masterchef,
        uint256 _pid
    ) external initializer {
        require(msg.sender == deployer);
        _initializeBase(_vaultchef, _zap, _underlyingToken, _rewardToken);

        masterchef = _masterchef;
        pid = _pid;
    }

    function _panic() internal override {
        masterchef.emergencyWithdraw(pid);
    }

    function _harvest() internal override {
        masterchef.deposit(pid, 0);
    }

    function _deposit(uint256 amount) internal override {
        underlyingToken.approve(address(masterchef), amount);
        masterchef.deposit(pid, amount);
    }

    function _withdraw(uint256 amount) internal override {
        masterchef.withdraw(pid, amount);
    }

    function _totalStaked() internal view override returns (uint256) {
        (uint256 amount, ) = masterchef.userInfo(pid, address(this));
        return amount;
    }
}