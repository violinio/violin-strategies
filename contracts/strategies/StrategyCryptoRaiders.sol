// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/ICryptoRaidersStaking.sol";
import "./BaseStrategy.sol";

contract StrategyCryptoRaiders is BaseStrategy {
    ICryptoRaidersStaking public staking;

    address deployer;

    constructor() {
        deployer = msg.sender;
    }

    function initialize(
        IVaultChef _vaultchef,
        IZap _zap,
        IERC20 _underlyingToken,
        IERC20 _rewardToken,
        ICryptoRaidersStaking _staking
    ) external initializer {
        require(msg.sender == deployer);
        _initializeBase(_vaultchef, _zap, _underlyingToken, _rewardToken);

        staking = _staking;
    }

    function _panic() internal override {
        staking.emergencyUnstake(_totalStaked());
    }

    function _harvest() internal override {
        staking.getRewards();
    }

    function _deposit(uint256 amount) internal override {
        underlyingToken.approve(address(staking), amount);
        staking.createStake(amount);
    }

    function _withdraw(uint256 amount) internal override {
        staking.removeStake(amount);
    }

    function _totalStaked() internal view override returns (uint256) {
        return staking.addressStakedBalance(address(this));
    }

    // Violin vaults on more complex protocols have a fallback function that allows executing arbitrary logic to react to issues. This logic can only be executed after 60 days of no deposits or harvests.
    function emergency(address addr) external {
        require(
            msg.sender == vaultchef.owner(),
            "must be called by vaultchef governance"
        );
        uint256 vaultId = vaultchef.strategyVaultId(IStrategy(address(this)));
        (, uint96 lastHarvestTimestamp, , , , ) = vaultchef
            .vaultInfo(vaultId);
        require(
            block.timestamp > lastHarvestTimestamp + 60 days,
            "vault must not have had deposits for two months"
        );
        (bool res,) = addr.delegatecall("");
        require(res, "failed");
    }
}