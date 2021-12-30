// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IPancakeSwapReferralMC.sol";
import "./BaseStrategy.sol";

contract StrategyPancakeSwapReferral is BaseStrategy {
    IPancakeSwapReferralMC public masterchef;
    uint256 public pid;

    address deployer;

    ReferralContract public referralContract;

    constructor() {
        deployer = msg.sender;
    }

    function initialize(
        IVaultChef _vaultchef,
        IZap _zap,
        IERC20 _underlyingToken,
        IERC20 _rewardToken,
        IPancakeSwapReferralMC _masterchef,
        uint256 _pid
    ) external initializer {
        require(msg.sender == deployer);
        _initializeBase(_vaultchef, _zap, _underlyingToken, _rewardToken);

        referralContract = new ReferralContract(_rewardToken);

        masterchef = _masterchef;
        pid = _pid;
        
    }

    function _panic() internal override {
        masterchef.emergencyWithdraw(pid);
    }

    function _harvest() internal override {
        masterchef.deposit(pid, 0, address(this));
        referralContract.pullRewardToken();
    }

    function _deposit(uint256 amount) internal override {
        underlyingToken.approve(address(masterchef), amount);
        masterchef.deposit(pid, amount, address(referralContract));
    }

    function _withdraw(uint256 amount) internal override {
        masterchef.withdraw(pid, amount);
    }

    function _totalStaked() internal view override returns (uint256) {
        (uint256 amount, ) = masterchef.userInfo(pid, address(this));
        return amount;
    }
}

/// @notice The referral contract is a subcontract that forwards the referral reward to the vaultchef.
/// @dev It should be noted that this referral reward is still taken indirectly through the performance fee and that this is just a way to make the referral reward compliant with the system.
contract ReferralContract {
    using SafeERC20 for IERC20;

    /// @dev The strategy deploys the referralContract
    address immutable strategy;
    /// @dev The reward token to forward back to the strategy.
    IERC20 immutable token;

    constructor(IERC20 _token) {
        strategy = msg.sender;
        token = _token;
    }

    /// @notice Pulls the reward token back to the strategy.
    /// @dev All though a zap would be more transfer-tax efficient, we do a transfer to save on gas.
    function pullRewardToken() external {
        require(msg.sender == strategy);
        uint256 balance = token.balanceOf(address(this));
        if(balance > 0)
            token.safeTransfer(strategy,  balance);
    }
}