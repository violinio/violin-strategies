// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IThorusMaster.sol";
import "./BaseStrategy.sol";

contract StrategyThorus is BaseStrategy {
    IThorusMasterchef public masterchef;
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
        IThorusMasterchef _masterchef,
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
        masterchef.claim(pid);
    }

    function _deposit(uint256 amount) internal override {
        underlyingToken.approve(address(masterchef), amount);
        masterchef.deposit(pid, amount, false);
    }

    function _withdraw(uint256 amount) internal override {
        masterchef.withdraw(pid, amount, false);
    }

    function _totalStaked() internal view override returns (uint256) {
        (uint256 amount,, ) = masterchef.userInfo(pid, address(this));
        return amount;
    }
}