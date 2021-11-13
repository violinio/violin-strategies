// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IVaultChef.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IZap.sol";

/**
 * @notice The BaseStrategy implements reusable logic for all Violin strategies that earn some single asset "rewardToken".
 * @dev It exposes a very simple interface which the actual strategies can implement.
 * @dev The zapper contract does not have excessive privileges and withdrawals should always be possible even if it reverts.
 */
abstract contract BaseStrategy is IStrategy {
    using SafeERC20 for IERC20;
    /// @dev Set to true once _initializeBase is called by the implementation.
    bool initialized;

    /// @dev The vaultchef contract this strategy is managed by.
    IVaultChef public vaultchef;
    /// @dev The zapper contract to swap earned for underlying tokens.
    IZap public zap;
    /// @dev The token that is actually staked into the underlying protocol.
    IERC20 public override underlyingToken;
    /// @dev The token the underlying protocol gives as a reward.
    IERC20 public rewardToken;

    modifier onlyVaultchef() {
        require(msg.sender == address(vaultchef), "!vaultchef");
        _;
    }

    modifier initializer() {
        require(!initialized, "!already initialized");
        _;
        // We unsure that the implementation has called _initializeBase during the external initialize function.
        require(initialized, "!not initialized");
    }

    /// @notice Initializes the base strategy variables, should be called together with contract deployment by a contract factory.
    function _initializeBase(
        IVaultChef _vaultchef,
        IZap _zap,
        IERC20 _underlyingToken,
        IERC20 _rewardToken
    ) internal {
        assert(!initialized); // No implementation should call _initializeBase without using the initialize modifier, hence we can assert.
        initialized = true;
        vaultchef = _vaultchef;
        zap = _zap;
        underlyingToken = _underlyingToken;
        rewardToken = _rewardToken;
    }

    /// @notice Deposits `amount` amount of underlying tokens in the underlying strategy.
    /// @dev Authority: This function must only be callable by the VaultChef.
    function deposit(uint256 amount) external override onlyVaultchef {
        _deposit(amount);
    }

    /// @notice Withdraws `amount` amount of underlying tokens to `to`.
    /// @dev Authority: This function must only be callable by the VaultChef.
    function withdraw(address to, uint256 amount)
        external
        override
        onlyVaultchef
    {
        uint256 idleUnderlying = underlyingToken.balanceOf(address(this));
        if (idleUnderlying < amount) {
            _withdraw(amount - idleUnderlying);
        }
        uint256 toWithdraw = underlyingToken.balanceOf(address(this));
        if (amount < toWithdraw) {
            toWithdraw = amount;
        }
        underlyingToken.safeTransfer(to, toWithdraw);
    }

    /// @notice Withdraws all funds from the underlying staking contract into the strategy.
    /// @dev This should ideally always work (eg. emergencyWithdraw instead of a normal withdraw on masterchefs).
    function panic() external override onlyVaultchef {
        _panic();
    }

    /// @notice Harvests the reward token from the underlying protocol, converts it to underlying tokens and deposits it again.
    /// @dev The whole rewardToken balance will be converted to underlying tokens, this might include tokens send to the contract by accident.
    /// @dev There is no way to exploit this, even when reward and earned tokens are identical since the vaultchef does not allow harvesting after a panic occurs.
    function harvest() external override onlyVaultchef {
        _harvest();

        if (rewardToken != underlyingToken) {
            uint256 rewardBalance = rewardToken.balanceOf(address(this));
            if (rewardBalance > 0) {
                rewardToken.approve(address(zap), rewardBalance);
                zap.swapERC20Fast(rewardToken, underlyingToken, rewardBalance);
            }
        }
        uint256 toDeposit = underlyingToken.balanceOf(address(this));
        if (toDeposit > 0) {
            _deposit(toDeposit);
        }
    }

    /// @notice Withdraws stuck ERC-20 tokens inside the strategy contract, cannot be staking or underlying.
    function inCaseTokensGetStuck(
        IERC20 token,
        uint256 amount,
        address to
    ) external override onlyVaultchef {
        require(
            token != underlyingToken && token != rewardToken,
            "invalid token"
        );
        require(!isTokenProhibited(token), "token prohibited");
        token.safeTransfer(to, amount);
    }

    function isTokenProhibited(IERC20) internal virtual returns(bool) {
        return false;
    }

    /// @notice Gets the total amount of tokens either idle in this strategy or staked in an underlying strategy.
    function totalUnderlying() external view override returns (uint256) {
        return underlyingToken.balanceOf(address(this)) + _totalStaked();
    }

    /// @notice Gets the total amount of tokens either idle in this strategy or staked in an underlying strategy and only the tokens actually staked.
    function totalUnderlyingAndStaked()
        external
        view
        override
        returns (uint256 _totalUnderlying, uint256 _totalUnderlyingStaked)
    {
        uint256 totalStaked = _totalStaked();
        return (
            underlyingToken.balanceOf(address(this)) + totalStaked,
            totalStaked
        );
    }

    ///** INTERFACE FOR IMPLEMENTATIONS **/

    /// @notice Should withdraw all staked funds to the strategy.
    function _panic() internal virtual;

    /// @notice Should harvest all earned rewardTokens to the strategy.
    function _harvest() internal virtual;

    /// @notice Should deposit `amount` from the strategy into the staking contract.
    function _deposit(uint256 amount) internal virtual;

    /// @notice Should withdraw `amount` from the staking contract, it is okay if there is a transfer tax and less is actually received.
    function _withdraw(uint256 amount) internal virtual;

    /// @notice Should withdraw `amount` from the staking contract, it is okay if there is a transfer tax and less is actually received.
    function _totalStaked() internal view virtual returns (uint256);
}
