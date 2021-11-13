// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../interfaces/IVaultChef.sol";
import "../interfaces/ISubFactory.sol";
import "../interfaces/IZapHandler.sol";
import "../interfaces/IZap.sol";

/// @notice The strategy factory is a utility contracts used by Violin to deploy new strategies more swiftly and securely.
/// @notice The admin can register strategy types together with a SubFactory that creates instances of the relevant strategy type.
/// @notice Examples of strategy types are MC_PCS_V1, MC_GOOSE_V1, MC_PANTHER_V1...
/// @notice Once a few types are registered, new strategies can be easily deployed by registering the relevant project and then instantiating strategies on that project.
/// @dev All strategy types, projects and individual strategies are stored as keccak256 hashes. The deployed strategies are identified by keccak256(keccak256(projectId), keccak256(strategyId)).
/// @dev VAULTCHEF AUTH: The StrategyFactory must have the ADD_VAULT_ROLE on the governor.
/// @dev ZAPGOVERNANCE AUTH: The StrategyFactory must have the

/// TODO: There is no createVault function!
contract StrategyFactory is AccessControlEnumerableUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    /// @notice The instance of the vaultChef to deploy strategies to.
    IVaultChef public vaultChef;

    /// @notice The zapper
    IZap public zap;

    //** STRATEGY TYPES **/
    /// @notice strategyTypes contains all registered hashed strategy types.
    EnumerableSetUpgradeable.Bytes32Set private strategyTypes;
    /// @notice Returns the registered subfactory of the strategy type. The subfactory is responsible for instantiating factories.
    mapping(bytes32 => ISubFactory) public subfactoryByType;

    mapping(address => bool) public isSubfactory;

    //** PROJECTS **/
    /// @notice All registered projects.
    EnumerableSetUpgradeable.Bytes32Set private projects;
    /// @notice The associated strategy type hash of the project. All strategies under the project will thus be deployed using the subfactory of this strategy type.
    mapping(bytes32 => bytes32) public projectStrategyType;
    /// @notice Generic parameters that will always be forwarded to the subfactory. This could for example be the native token.
    mapping(bytes32 => bytes) public projectParams;
    /// @notice Metadata associated with the project that can be used on the frontend, expected to be encoded in UTF-8 JSON.
    /// @notice Even though not ideomatic, this is a cheap solution to avoid infrastructure downtime within the first months after launch.
    mapping(bytes32 => bytes) public projectMetadata;

    /// @notice List of strategies registered for the project.
    mapping(bytes32 => EnumerableSetUpgradeable.Bytes32Set)
        private projectStrategies;

    //** STRATEGIES **/

    /// @notice All registered strategies.
    /// @dev These are identified as keccak256(abi.encodePacked(keccak256(projectId), keccak256(strategyId))).
    EnumerableSetUpgradeable.Bytes32Set private strategies;
    /// @notice Metadata associated with the strategy that can be used on the frontend, expected to be encoded in UTF-8 JSON.
    /// @notice Even though not ideomatic, this is a cheap solution to avoid infrastructure downtime within the first months after launch.
    mapping(bytes32 => bytes) public strategyMetadata;

    /// @notice Gets the vaultId associated with the strategyId.
    mapping(bytes32 => uint256) private strategyToVaultId;
    /// @notice Gets the strategy id associated with the vaultId.
    mapping(uint256 => bytes32) public vaultIdToStrategy;

    /// @notice gets all strategy ids associated with an underlying token.
    mapping(IERC20 => EnumerableSetUpgradeable.Bytes32Set)
        private underlyingToStrategies;

    bytes32 public constant REGISTER_STRATEGY_ROLE =
        keccak256("REGISTER_STRATEGY_ROLE");
    bytes32 public constant REGISTER_PROJECT_ROLE =
        keccak256("REGISTER_PROJECT_ROLE");
    bytes32 public constant CREATE_VAULT_ROLE = keccak256("CREATE_VAULT_ROLE");

    event StrategyTypeAdded(
        bytes32 indexed strategyType,
        ISubFactory indexed subfactory
    );
    event ProjectRegistered(
        bytes32 indexed projectId,
        bytes32 indexed strategyType,
        bool indexed isUpdate
    );
    event VaultRegistered(
        uint256 indexed vaultId,
        bytes32 indexed projectId,
        bytes32 indexed strategyId,
        bool isUpdate
    );

    function initialize(IVaultChef _vaultChef, IZap _zap) external initializer {
        __AccessControlEnumerable_init();

        vaultChef = _vaultChef;
        zap = _zap;
        vaultChef.poolLength(); // validate vaultChef

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(REGISTER_STRATEGY_ROLE, msg.sender);
        _setupRole(REGISTER_PROJECT_ROLE, msg.sender);
        _setupRole(CREATE_VAULT_ROLE, msg.sender);
    }

    function registerStrategyType(
        string calldata strategyType,
        ISubFactory subfactory
    ) external onlyRole(REGISTER_STRATEGY_ROLE) {
        registerStrategyTypeRaw(
            keccak256(abi.encodePacked(strategyType)),
            subfactory
        );
    }

    function registerStrategyTypeRaw(
        bytes32 strategyType,
        ISubFactory subfactory
    ) public onlyRole(REGISTER_STRATEGY_ROLE) {
        require(!strategyTypes.contains(strategyType), "!exists");
        strategyTypes.add(strategyType);
        subfactoryByType[strategyType] = subfactory;
        isSubfactory[address(subfactory)] = true;

        emit StrategyTypeAdded(strategyType, subfactory);
    }

    function registerProject(
        string calldata projectId,
        string calldata strategyType,
        bytes calldata params,
        bytes calldata metadata
    ) external onlyRole(REGISTER_PROJECT_ROLE) {
        registerProjectRaw(
            keccak256(abi.encodePacked(projectId)),
            keccak256(abi.encodePacked(strategyType)),
            params,
            metadata
        );
    }

    function registerProjectRaw(
        bytes32 projectId,
        bytes32 strategyType,
        bytes calldata params,
        bytes calldata metadata
    ) public onlyRole(REGISTER_PROJECT_ROLE) {
        require(
            strategyTypes.contains(strategyType),
            "!strategyType not found"
        );
        bool exists = projects.contains(projectId);
        projectStrategyType[projectId] = strategyType;
        projectParams[projectId] = params;
        projectMetadata[projectId] = metadata;

        emit ProjectRegistered(projectId, strategyType, exists);
    }

    struct CreateVaultVars {
        bytes32 strategyUID;
        bool exists;
        IStrategy strategy;
        uint256 vaultId;
        bytes projectParams;
    }

    function createVault(
        string calldata projectId,
        string calldata strategyId,
        IERC20 underlyingToken,
        bytes calldata params,
        bytes calldata metadata,
        uint16 performanceFee
    ) external onlyRole(CREATE_VAULT_ROLE) returns (uint256, IStrategy) {
        return
            createVaultRaw(
                keccak256(abi.encodePacked(projectId)),
                keccak256(abi.encodePacked(strategyId)),
                underlyingToken,
                params,
                metadata,
                performanceFee
            );
    }

    function createVaultRaw(
        bytes32 projectId,
        bytes32 strategyId,
        IERC20 underlyingToken,
        bytes calldata params,
        bytes calldata metadata,
        uint16 performanceFee
    ) public onlyRole(CREATE_VAULT_ROLE) returns (uint256, IStrategy) {
        CreateVaultVars memory vars;

        vars.strategyUID = getStrategyUID(projectId, strategyId);
        vars.exists = strategies.contains(vars.strategyUID);
        vars.projectParams = projectParams[projectId];

        vars.strategy = subfactoryByType[projectStrategyType[projectId]]
            .deployStrategy(
                vaultChef,
                underlyingToken,
                vars.projectParams,
                params
            );
        vars.vaultId = vaultChef.poolLength();
        IVaultChef(vaultChef.owner()).addVault(vars.strategy, performanceFee); // .owner to get the governor which inherits the vaultchef interface

        strategyMetadata[vars.strategyUID] = metadata;

        // Indexing
        projectStrategies[projectId].add(vars.strategyUID);
        vaultIdToStrategy[vars.vaultId] = vars.strategyUID;
        strategyToVaultId[vars.strategyUID] = vars.vaultId;
        underlyingToStrategies[vars.strategy.underlyingToken()].add(
            vars.strategyUID
        );

        emit VaultRegistered(vars.vaultId, projectId, strategyId, vars.exists);
        return (vars.vaultId, vars.strategy);
    }

    function setRoute(address[] calldata route) external {
        require(isSubfactory[msg.sender], "!subfactory");
        // Only set the route if it actually exists.
        if (route.length > 0) {
            IERC20 from = IERC20(route[0]);
            IERC20 to = IERC20(route[route.length - 1]);
            IZapHandler zapHandler = IZapHandler(
                IZapHandler(zap.implementation()).owner()
            ); // go to the governance contract which mimics the IZapHandler interface
            if (zapHandler.routeLength(from, to) == 0) {
                zapHandler.setRoute(from, to, route);
            }
        }
    }

    function getStrategyUID(bytes32 projectId, bytes32 strategyId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(projectId, strategyId));
    }

    //** VIEW FUNCTIONS **//

    //** strategy types **/

    /// @notice Returns whether the unhashed `strategyType` is registered.
    function isStrategyType(string calldata strategyType)
        external
        view
        returns (bool)
    {
        return isStrategyTypeRaw(keccak256(abi.encodePacked(strategyType)));
    }

    /// @notice Returns whether the hashed `strategyType` is registered.
    function isStrategyTypeRaw(bytes32 strategyType)
        public
        view
        returns (bool)
    {
        return strategyTypes.contains(strategyType);
    }

    /// @notice Gets the length of the strategyType listing.
    function getStrategyTypeLength() public view returns (uint256) {
        return strategyTypes.length();
    }

    /// @notice Gets the strategyType hash at a specific index in the listing.
    function getStrategyTypeAt(uint256 index) public view returns (bytes32) {
        return strategyTypes.at(index);
    }

    /// @notice Lists the strategyType hashes within a specific range in the listing.
    function getStrategyTypes(uint256 from, uint256 amount)
        public
        view
        returns (bytes32[] memory)
    {
        return getPaginated(strategyTypes, from, amount);
    }

    //** projects **/

    /// @notice Returns whether the unhashed `projectId` is registered.
    function isProject(string calldata projectId) external view returns (bool) {
        return isStrategyTypeRaw(keccak256(abi.encodePacked(projectId)));
    }

    /// @notice Returns whether the hashed `projectId` is registered.
    function isProjectRaw(bytes32 projectId) public view returns (bool) {
        return strategyTypes.contains(projectId);
    }

    /// @notice Gets the length of the projects listing.
    function getProjectsLength() public view returns (uint256) {
        return projects.length();
    }

    /// @notice Gets the project hash at a specific index in the listing.
    function getProjectAt(uint256 index) public view returns (bytes32) {
        return projects.at(index);
    }

    /// @notice Lists the project hashes within a specific range in the listing.
    function getProjects(uint256 from, uint256 amount)
        public
        view
        returns (bytes32[] memory)
    {
        return getPaginated(projects, from, amount);
    }

    /// @notice Gets the length (number) of strategies of a project listing.
    function getProjectStrategiesLength(string calldata projectId)
        external
        view
        returns (uint256)
    {
        return
            getProjectStrategiesLengthRaw(
                keccak256(abi.encodePacked(projectId))
            );
    }

    /// @notice Gets the length (number) of strategies of a project listing.
    function getProjectStrategiesLengthRaw(bytes32 projectId)
        public
        view
        returns (uint256)
    {
        return projectStrategies[projectId].length();
    }

    /// @notice Gets the project's strategy hash at a specific index in the listing.
    function getProjectStrategyAt(string calldata projectId, uint256 index)
        external
        view
        returns (bytes32)
    {
        return
            getProjectStrategyAtRaw(
                keccak256(abi.encodePacked(projectId)),
                index
            );
    }

    /// @notice Gets the project's strategy hash at a specific index in the listing.
    function getProjectStrategyAtRaw(bytes32 projectId, uint256 index)
        public
        view
        returns (bytes32)
    {
        return projectStrategies[projectId].at(index);
    }

    /// @notice Lists the project's strategy hashes within a specific range in the listing.
    function getProjectStrategies(
        string calldata projectId,
        uint256 from,
        uint256 amount
    ) external view returns (bytes32[] memory) {
        return
            getProjectStrategiesRaw(
                keccak256(abi.encodePacked(projectId)),
                from,
                amount
            );
    }

    /// @notice Lists the project's strategy hashes within a specific range in the listing.
    function getProjectStrategiesRaw(
        bytes32 projectId,
        uint256 from,
        uint256 amount
    ) public view returns (bytes32[] memory) {
        return getPaginated(projectStrategies[projectId], from, amount);
    }

    //** strategies **/

    /// @notice Gets the length (number) of strategies of a project listing.
    function getStrategiesLength() external view returns (uint256) {
        return strategies.length();
    }

    /// @notice Gets the strategy hash at a specific index in the listing.
    function getStrategyAt(uint256 index) external view returns (bytes32) {
        return strategies.at(index);
    }

    /// @notice Lists the strategy hashes within a specific range in the listing.
    function getStrategies(uint256 from, uint256 amount)
        external
        view
        returns (bytes32[] memory)
    {
        return getPaginated(strategies, from, amount);
    }

    //** underlying */

    /// @notice Gets the length (number) of strategies of a project listing.
    function getUnderlyingStrategiesLength(IERC20 token)
        external
        view
        returns (uint256)
    {
        return underlyingToStrategies[token].length();
    }

    /// @notice Gets the underlying tokens's strategy hash at a specific index in the listing.
    function getUnderlyingStrategyAt(IERC20 token, uint256 index)
        external
        view
        returns (bytes32)
    {
        return underlyingToStrategies[token].at(index);
    }

    /// @notice Lists the underlying tokens's strategy hashes within a specific range in the listing.
    function getUnderlyingStrategies(
        IERC20 token,
        uint256 from,
        uint256 amount
    ) external view returns (bytes32[] memory) {
        return getPaginated(underlyingToStrategies[token], from, amount);
    }

    function getPaginated(
        EnumerableSetUpgradeable.Bytes32Set storage set,
        uint256 from,
        uint256 amount
    ) private view returns (bytes32[] memory) {
        uint256 length = set.length();
        if (from >= length) {
            return new bytes32[](0);
        }

        if (from + amount > length) {
            amount = length - from;
        }

        bytes32[] memory types = new bytes32[](amount);
        for (uint256 i = 0; i < amount; i++) {
            types[i] == strategyTypes.at(from + i);
        }
        return types;
    }
}
