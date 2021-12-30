// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@violinio/defi-interfaces/contracts/IPancakeSwapMC.sol";
import "../interfaces/ISubFactory.sol";
import "../strategies/StrategyPancakeSwapStaking.sol";
import "./StrategyFactory.sol";
/**
 * Project data: (address masterchef, address rewardToken)
 * Strategy data: (uint256 pid)
 */
contract PancakeSwapStakingFactory is ISubFactory {
    StrategyFactory public immutable strategyFactory;
    IZap public zap;

    constructor(StrategyFactory _strategyFactory, IZap _zap) {
        strategyFactory = _strategyFactory;
        zap = _zap;
    }

    function deployStrategy(
        IVaultChef vaultChef,
        IERC20 underlyingToken,
        bytes calldata projectData,
        bytes calldata strategyData
    ) external override returns (IStrategy) {
        require(msg.sender == address(strategyFactory));
        (address masterchefAddress, address rewardToken) = abi.decode(projectData, (address, address));
        (address[] memory route) = abi.decode(strategyData, (address[]));
        // validate underlying masterchef
        IPancakeSwapMC masterchef = IPancakeSwapMC(masterchefAddress);
        _validateMasterchef(masterchef, underlyingToken);
        
        // initialize strategy
        StrategyPancakeSwapStaking strategy = new StrategyPancakeSwapStaking();
        strategy.initialize(vaultChef, zap, underlyingToken, IERC20(rewardToken), masterchef);
        
        // set swap route
        if (route.length > 0) {
            strategyFactory.setRoute(route);
        }
        return strategy;
    }

    function _validateMasterchef(IPancakeSwapMC masterchef, IERC20 underlyingToken) internal view {
        try  masterchef.poolLength() returns (
            uint256 length
        ) {
            require(length > 0, "pool nonexistent");
        } catch {
            revert("!incorrect poolLength");
        }
        try  masterchef.userInfo(0, address(this)) returns (uint256 amount, uint256 rewardDebt) {
            amount;rewardDebt;//sh
        } catch {
            revert("!incorrect userInfo");
        }

        require(getPoolToken(masterchef, 0) == address(underlyingToken), "!underlying");
    }

    function getPoolToken(IPancakeSwapMC mc, uint256 pid) public view returns (address) {
        (bool success, bytes memory data) = address(mc).staticcall(abi.encodeWithSignature("poolInfo(uint256)", pid));
        require(data.length >= 32, "!data");
        require(success, "!fallback poolInfo failed");
        
        return getAddressFromBytes(data);
    }        

    /// @dev converts the return data to the first address found in it (pads 12 bytes because address only ocupies 20/32 bytes.)
    function getAddressFromBytes(bytes memory _address) internal pure returns (address) {
        uint160 m = 0;
        uint8 b = 0;

        for (uint8 i = 12; i < 32; i++) {
            m *= 256;
            b = uint8(_address[i]);
            m += b;
        }
        return address(m);
    }
}