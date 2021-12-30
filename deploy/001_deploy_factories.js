

const delay = ms => new Promise(res => setTimeout(res, ms));
const etherscanChains = ["poly", "bsc", "poly_mumbai", "ftm", "arbitrum", "avax", "avax_fuji"];
const sourcifyChains = ["xdai", "celo", "arbitrum"];

const { VAULTCHEF, ZAP } = process.env;
// TODO: add vaultChefs here.
const vaultchefs = {
    "avax": "0xF2188e17A3B33902CEAA645F8470904Eb0ce943f",
    "bsc": "0x9166933Bd5c8A77E99B149c5A32f0936aD6aaE25",
    "celo": "0x76cb8cd4b0a55C6dE2bd864dEd2B55140bB56C18",
    "ftm": "0x76cb8cd4b0a55C6dE2bd864dEd2B55140bB56C18",
    "cro": "0x2926FaBf8eF4880B2C32Fc84B1CA7C38ee045F9b",
    "fuse": "0xA5BCB9FdDE71e393978278999425ac42DA393d3D",
    "aurora": "0xA5BCB9FdDE71e393978278999425ac42DA393d3D",
    "harmony": "0xA5BCB9FdDE71e393978278999425ac42DA393d3D",
};

const zaps = {
    "avax": "0xAfEf94984f3C3665e72F1a8d4634659621dA18A0",
    "bsc": "0xAfEf94984f3C3665e72F1a8d4634659621dA18A0",
    "celo": "0xAfEf94984f3C3665e72F1a8d4634659621dA18A0",
    "ftm": "0xAfEf94984f3C3665e72F1a8d4634659621dA18A0",
    "cro": "0xAfEf94984f3C3665e72F1a8d4634659621dA18A0",
    "fuse": "0xAfEf94984f3C3665e72F1a8d4634659621dA18A0",
    "aurora": "0xAfEf94984f3C3665e72F1a8d4634659621dA18A0",
    "harmony": "0xAfEf94984f3C3665e72F1a8d4634659621dA18A0",

};

const main = async function (hre) {
    const chain = hre.network.name;
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const signer = await hre.ethers.getSigner(deployer);
    let vaultchef = VAULTCHEF;
    if (VAULTCHEF === undefined || VAULTCHEF === "") {
        vaultchef = vaultchefs[chain];
    }

    let zap = ZAP;
    if (ZAP === undefined || ZAP === "") {
        zap = zaps[chain];
    }

    // We get the contract to deploy
    const factory = await deploy("StrategyFactory", {
        from: deployer,
        proxy: {
            execute: {
                init: {
                    methodName: 'initialize',
                    args: [vaultchef, zap, signer.address]
                },
            },
        },
        deterministicDeployment: "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb659",// salt
        log: true
    });
    console.log("StrategyFactory deployed to:", factory.address);
    console.log("StrategyFactory implementation deployed to:", factory.implementation);


    const factoryFactory = await ethers.getContractFactory("StrategyFactory");
    const factoryContract = await factoryFactory.attach(factory.address);
    
    const pcsFactory = await deploy("PancakeSwapFactory", {
        from: deployer,
        args: [factory.address, zap],
        deterministicDeployment: "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb659",// salt
        log: true
    });

    if (!(await factoryContract.isSubfactory(pcsFactory.address))) {
        console.log('registering pancakeswap factory...');
        await factoryContract.connect(signer).registerStrategyType("PANCAKESWAP_MC4", pcsFactory.address);
        console.log("registered pancakeswap factory");
    }

    const stakingRewardsFactory = await deploy("StakingRewardsFactory", {
        from: deployer,
        args: [factory.address, zap],
        deterministicDeployment: "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb659",// salt
        log: true
    });

    if (!(await factoryContract.isSubfactory(stakingRewardsFactory.address))) {
        console.log('registering staking rewards factory...');
        await factoryContract.connect(signer).registerStrategyType("STAKING_REWARDS2", stakingRewardsFactory.address);
        console.log("registered staking rewards factory");
    }

    const pcsStakingFactory = await deploy("PancakeSwapStakingFactory", {
        from: deployer,
        args: [factory.address, zap],
        deterministicDeployment: "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb659",// salt
        log: true
    });

    if (!(await factoryContract.isSubfactory(pcsStakingFactory.address))) {
        console.log('registering pancakeswap staking factory...');
        await factoryContract.connect(signer).registerStrategyType("PANCAKESWAP_MC_STAKING", pcsStakingFactory.address);
        console.log("registered pancakeswap staking factory");
    }

    const sushiMiniChefV2Factory = await deploy("SushiMiniChefV2Factory", {
        from: deployer,
        args: [factory.address, zap],
        deterministicDeployment: "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb659",// salt
        log: true
    });

    if (!(await factoryContract.isSubfactory(sushiMiniChefV2Factory.address))) {
        console.log('registering sushi minichef v2 factory...');
        await factoryContract.connect(signer).registerStrategyType("SUSHI_MINICHEF_V2", sushiMiniChefV2Factory.address);
        console.log("registered sushi minichef v2 factory");
    }

    console.log("sushi StrategyFactory deployed to:", sushiMiniChefV2Factory.address);

    if (chain === "fuse") {
        const fuseFiStakingFactory = await deploy("FuseFiStakingFactory", {
            from: deployer,
            args: [factory.address, zap],
            deterministicDeployment: "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb659",// salt
            log: true
        });

        if (!(await factoryContract.isSubfactory(fuseFiStakingFactory.address))) {
            console.log('registering fusefi factory...');
            await factoryContract.connect(signer).registerStrategyType("FUSEFI_MULTI_REWARDS", fuseFiStakingFactory.address);
            console.log("registered fusefi factory");
        }

        try {
            await verify(hre, chain, fuseFiStakingFactory.address, [factory.address, zap]);
        } catch { }
    }

    const pancakeReferralFactory = await deploy("PancakeSwapReferralFactory", {
        from: deployer,
        args: [factory.address, zap],
        deterministicDeployment: "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb659",// salt
        log: true
    });
    if (!(await factoryContract.isSubfactory(pancakeReferralFactory.address))) {
        console.log('registering pancakeReferralFactory...');
        await factoryContract.connect(signer).registerStrategyType("PANCAKESWAP_REFERRAL_MC", pancakeReferralFactory.address);
        console.log("registered pancakeReferralFactory");
    }
    console.log("pancakeReferralFactory deployed to:", pancakeReferralFactory.address);

    if (chain === "harmony") {
        const wagmiEarnFactory = await deploy("WagmiEarnFactory", {
            from: deployer,
            args: [factory.address, zap],
            deterministicDeployment: "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb659",// salt
            log: true
        });

        if (!(await factoryContract.isSubfactory(wagmiEarnFactory.address))) {
            console.log('registering wagmi earn factory...');
            await factoryContract.connect(signer).registerStrategyType("WAGMI_EARN", wagmiEarnFactory.address);
            console.log("registered wagmi earn factory");
        }
        console.log("wagmi earn deployed to:", wagmiEarnFactory.address);

        try {
            await verify(hre, chain, wagmiEarnFactory.address, [factory.address, zap]);
        } catch { }
    }


    try {
        await verify(hre, chain, factory.implementation, []);
    } catch { }

    try {
        await verify(hre, chain, pcsFactory.address, [factory.address, zap]);
    } catch {

    }

    try {
        await verify(hre, chain, sushiMiniChefV2Factory.address, [factory.address, zap]);
    } catch { }
}

async function verify(hre, chain, contract, args) {
    const isEtherscanAPI = etherscanChains.includes(chain);
    const isSourcify = sourcifyChains.includes(chain);
    if (!isEtherscanAPI && !isSourcify)
        return;

    console.log('verifying...');
    await delay(5000);
    if (isEtherscanAPI) {
        const apikey = process.env.ETHERSCAN_APIKEY;
        if (apikey === undefined || apikey === "") {
            console.log("NO APIKEY");
        }
        await hre.run("verify:verify", {
            address: contract,
            network: chain,
            constructorArguments: args
        });
    } else if (isSourcify) {
        try {
            await hre.run("sourcify", {
                address: contract,
                network: chain,
                constructorArguments: args
            });
        } catch (error) {
            console.log("verification failed: sourcify not supported?");
        }
    }
}

module.exports = main;