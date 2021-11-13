// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/ISushiMiniChefV2.sol";
import "./BaseStrategyMulti.sol";

contract StrategyPancakeSwap is BaseStrategyMulti {
    ISushiMiniChefV2 public minichef;
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
        ISushiMiniChefV2 _minichef,
        uint256 _pid
    ) external initializer {
        require(msg.sender == deployer);
        _initializeBase(_vaultchef, _zap, _underlyingToken, _rewardTokens);

        minichef = _minichef;
        pid = _pid;
    }

    function _panic() internal override {
        minichef.emergencyWithdraw(pid, address(this));
    }

    function _harvest() internal override {
        minichef.harvest(pid, address(this));
    }

    function _deposit(uint256 amount) internal override {
        underlyingToken.approve(address(minichef), amount);
        minichef.deposit(pid, amount, address(this));
    }

    function _withdraw(uint256 amount) internal override {
        require(
            address(underlyingToken) == minichef.lpToken(pid),
            "minichef may not have migrated"
        );
        minichef.withdraw(pid, amount, address(this));
    }

    function _totalStaked() internal view override returns (uint256) {
        (uint256 amount, ) = minichef.userInfo(pid, address(this));
        return amount;
    }

    /// @notice handleSushiMigration is an extremely defensively written governance function which allows to react to the fact that sushi has given themselves privileges to move to a new LP token.
    /// @notice This function allows to reverse this process after the vault has panicked for a long enough time. It should be noted that as long as the vault is panicked, users will have pennies on the dollar
    /// @notice because there are no underlyingTokens in this contract as sushi migrated them to a new one.
    /// @notice It is therefore of utmost importance to educate the community not to emergencyWithdraw in this situation, as they will forfeit all their shares which value could be recovered with this function.
    /// @notice To combat this scenario, we added a requirement to withdraw that the minichef is not allowed to have migrated.
    /// @notice The correct sequence of events is therefore: Migration happens -> pause for 30 days -> panic and handleSushiMigration immediately after eachother.
    function handleSushiMigration(IMigrationHandler migrationHandler) external {
        require(
            msg.sender == vaultchef.owner(),
            "must be called by vaultchef governance"
        );
        IERC20 newLPToken = IERC20(minichef.lpToken(pid));
        require(
            underlyingToken != newLPToken,
            "minichef must have migrated"
        );
        uint256 vaultId = vaultchef.strategyVaultId(IStrategy(address(this)));
        (, uint96 lastHarvestTimestamp, , , , bool panicked) = vaultchef
            .vaultInfo(vaultId);
        require(panicked, "vault must be panicked");
        require(
            block.timestamp > lastHarvestTimestamp + 30 days,
            "vault must not have had deposits for one months"
        );
        uint256 bal = newLPToken.balanceOf(address(this));
        newLPToken.approve(address(migrationHandler), bal);
        migrationHandler.handleMigration(bal);
        newLPToken.approve(address(migrationHandler), 0);
        require(underlyingToken.balanceOf(address(this)) >= bal);
    }

    // We prohibit the withdrawal of the new LP token by the vaultchef governance, if sushi ever decides to migrate.
    function isTokenProhibited(IERC20 token) internal override view returns (bool) {
        return address(token) == minichef.lpToken(pid);
    }
}

interface IMigrationHandler {
    function handleMigration(uint256 amount) external;
}
