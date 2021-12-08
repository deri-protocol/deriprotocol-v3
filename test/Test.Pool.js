require('@nomiclabs/hardhat-ethers')
require('hardhat')

MAX = ethers.BigNumber.from('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')
ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
DEADLINE = parseInt(Date.now() / 1000) + 86400

bb = function (value, decimals=18) {
    return ethers.utils.parseUnits(value.toString(), decimals)
}

describe('Test Pool', function () {
    this.timeout(1000000)

    beforeEach(async function () {
        accounts = await ethers.getSigners()

        // token
        busd = await (await ethers.getContractFactory('TERC20')).deploy('Test BUSD', 'BUSD', 18)
        cake = await (await ethers.getContractFactory('TERC20')).deploy('Test CAKE', 'CAKE', 18)

        // venus
        priceOracle = await (await ethers.getContractFactory('SimplePriceOracle')).deploy()
        unitroller = await (await ethers.getContractFactory('Unitroller')).deploy()
        comptroller = await (await ethers.getContractFactory('Comptroller')).deploy()
        await unitroller._setPendingImplementation(comptroller.address)
        await comptroller._become(unitroller.address)
        comptroller = await ethers.getContractAt('Comptroller', unitroller.address)
        await comptroller._setLiquidationIncentive(bb(1))
        await comptroller._setCloseFactor(bb(0.051))
        await comptroller._setPriceOracle(priceOracle.address)
        interestRateModel = await (await ethers.getContractFactory('WhitePaperInterestRateModel')).deploy(bb(1), bb(1))

        vBNB = await (await ethers.getContractFactory('VBNB')).deploy(
            comptroller.address, interestRateModel.address, bb(1), 'VToken vBNB', 'vBNB', 8, accounts[0].address
        )
        await priceOracle.setUnderlyingPrice(vBNB.address, bb(5000))
        await comptroller._supportMarket(vBNB.address)
        await comptroller._setCollateralFactor(vBNB.address, bb(0.8))

        vBUSDDelegatee = await (await ethers.getContractFactory('VBep20Delegate')).deploy()
        vBUSDDelegator = await (await ethers.getContractFactory('VBep20Delegator')).deploy(
            busd.address, comptroller.address, interestRateModel.address, bb(1), 'VToken vBUSD', 'vBUSD', 8, accounts[0].address, vBUSDDelegatee.address, '0x'
        )
        vBUSD = await ethers.getContractAt('VBep20Delegate', vBUSDDelegator.address)
        await comptroller._supportMarket(vBUSD.address)
        await comptroller._setCollateralFactor(vBUSD.address, bb(0.8))

        vCAKEDelegatee = await (await ethers.getContractFactory('VBep20Delegate')).deploy()
        vCAKEDelegator = await (await ethers.getContractFactory('VBep20Delegator')).deploy(
            cake.address, comptroller.address, interestRateModel.address, bb(1), 'VToken vCAKE', 'vCAKE', 8, accounts[0].address, vCAKEDelegatee.address, '0x'
        )
        vCAKE = await ethers.getContractAt('VBep20Delegate', vCAKEDelegator.address)
        await priceOracle.setUnderlyingPrice(vCAKE.address, bb(20))
        await comptroller._supportMarket(vCAKE.address)
        await comptroller._setCollateralFactor(vCAKE.address, bb(0.5))

        // swap
        wbnb = await (await ethers.getContractFactory('WETH9')).deploy()
        factory = await (await ethers.getContractFactory('UniswapV2Factory')).deploy(accounts[0].address)
        router = await (await ethers.getContractFactory('UniswapV2Router02')).deploy(factory.address, wbnb.address)

        await vBNB.connect(accounts[0]).mint({value: bb(500)})
        await busd.mint(accounts[0].address, bb(2500000))
        await busd.connect(accounts[0]).approve(vBUSD.address, MAX)
        await vBUSD.connect(accounts[0]).mint(bb(2500000))
        await cake.mint(accounts[0].address, bb(150000))
        await cake.connect(accounts[0]).approve(vCAKE.address, MAX)
        await vCAKE.connect(accounts[0]).mint(bb(150000))

        await busd.approve(router.address, MAX)
        await busd.mint(accounts[0].address, bb(1000000))
        await router.addLiquidityETH(busd.address, bb(1000000), 0, 0, accounts[0].address, DEADLINE, {value: bb(2000)})
        await cake.approve(router.address, MAX)
        await cake.mint(accounts[0].address, bb(50000))
        await router.addLiquidityETH(cake.address, bb(50000), 0, 0, accounts[0].address, DEADLINE, {value: bb(2000)})

        // oracle
        oracleManager = await (await ethers.getContractFactory('OracleManager')).deploy()
        oracleBNB = await (await ethers.getContractFactory('TestOracle')).deploy('BNBUSD')
        oracleCAKE = await (await ethers.getContractFactory('TestOracle')).deploy('CAKEUSD')
        await oracleBNB.setValue(bb(500))
        await oracleCAKE.setValue(bb(20))
        await oracleManager.setOracle(oracleBNB.address)
        await oracleManager.setOracle(oracleCAKE.address)
        oracleBTCUSD = await (await ethers.getContractFactory('TestOracle')).deploy('BTCUSD')
        oracleBTCUSD.setValue(bb(50000))
        await oracleManager.setOracle(oracleBTCUSD.address)
        oracleETHUSD = await (await ethers.getContractFactory('TestOracle')).deploy('ETHUSD')
        oracleETHUSD.setValue(bb(4000))
        await oracleManager.setOracle(oracleETHUSD.address)
        oracleVolatilityBTCUSD = await (await ethers.getContractFactory('TestOracle')).deploy('VOL-BTCUSD')
        oracleVolatilityBTCUSD.setValue(bb(0.9))
        await oracleManager.setOracle(oracleVolatilityBTCUSD.address)
        oracleVolatilityETHUSD = await (await ethers.getContractFactory('TestOracle')).deploy('VOL-ETHUSD')
        oracleVolatilityETHUSD.setValue(bb(1.1))
        await oracleManager.setOracle(oracleVolatilityETHUSD.address)

        // swapper
        swapper = await (await ethers.getContractFactory('Swapper')).deploy(
            factory.address, router.address, oracleManager.address, busd.address, wbnb.address, bb(0.1), 'BNBUSD'
        )
        await swapper.setPath('CAKEUSD', [busd.address, wbnb.address, cake.address])

        // pool
        pool = await (await ethers.getContractFactory('Pool')).deploy()

        // symbol manager
        symbolManager = await (await ethers.getContractFactory('SymbolManager')).deploy()
        symbolManagerImplementation = await (await ethers.getContractFactory('SymbolManagerImplementation')).deploy(pool.address)
        await symbolManager.setImplementation(symbolManagerImplementation.address)
        symbolManager = await ethers.getContractAt('SymbolManagerImplementation', symbolManager.address)

        // vault
        vaultTemplate = await (await ethers.getContractFactory('Vault')).deploy(pool.address)
        vaultImplementation = await (await ethers.getContractFactory('VaultImplementation')).deploy(pool.address, comptroller.address, vBNB.address, bb(1.25))

        // lToken pToken
        lToken = await (await ethers.getContractFactory('DToken')).deploy('Deri Liquidity Token', 'DLT', pool.address)
        pToken = await (await ethers.getContractFactory('DToken')).deploy('Deri Position Token', 'DPT', pool.address)

        poolImplementation = await (await ethers.getContractFactory('PoolImplementation')).deploy(
            [vaultTemplate.address, vaultImplementation.address, busd.address, wbnb.address, vBUSD.address, vBNB.address, lToken.address, pToken.address, swapper.address, symbolManager.address], [bb(0.25), bb(0.05), bb(10), bb(0.2), bb(10), bb(1000), bb(0.5)]
        )
        await pool.setImplementation(poolImplementation.address)
        pool = await ethers.getContractAt('PoolImplementation', pool.address)

        // symbols
        symbolBTCUSD = await (await ethers.getContractFactory('Symbol')).deploy('BTCUSD')
        symbolImplementationBTCUSD = await (await ethers.getContractFactory('SymbolImplementationFutures')).deploy(
            symbolManager.address, oracleManager.address, 'BTCUSD',
            [bb(0.001), bb(0.02), 86400, bb(0.001), bb(0.1), bb(0.05), bb(0.01), 3600], false
        )
        await symbolBTCUSD.setImplementation(symbolImplementationBTCUSD.address)
        symbolBTCUSD = await ethers.getContractAt('SymbolImplementationFutures', symbolBTCUSD.address)

        symbolETHUSD = await (await ethers.getContractFactory('Symbol')).deploy('ETHUSD')
        symbolImplementationETHUSD = await (await ethers.getContractFactory('SymbolImplementationFutures')).deploy(
            symbolManager.address, oracleManager.address, 'ETHUSD',
            [bb(0.002), bb(0.02), 86400, bb(0.01), bb(0.1), bb(0.05), bb(0.02), 3600], false,
        )
        await symbolETHUSD.setImplementation(symbolImplementationETHUSD.address)
        symbolETHUSD = await ethers.getContractAt('SymbolImplementationFutures', symbolETHUSD.address)

        symbolOptionBTCUSD = await (await ethers.getContractFactory('Symbol')).deploy('BTCUSD-60000-C')
        symbolImplementationOptionBTCUSD = await (await ethers.getContractFactory('SymbolImplementationOption')).deploy(
            symbolManager.address, oracleManager.address,
            ['BTCUSD-60000-C', 'BTCUSD', 'VOL-BTCUSD'],
            [bb(0.001), bb(0.04), bb(60000), bb(0.02), 86400, bb(0.001), bb(0.01), bb(0.1), bb(0.05), bb(0.01), 3600],
            [true, false]
        )
        symbolOptionBTCUSD.setImplementation(symbolImplementationOptionBTCUSD.address)
        symbolOptionBTCUSD = await ethers.getContractAt('SymbolImplementationOption', symbolOptionBTCUSD.address)

        symbolOptionETHUSD = await (await ethers.getContractFactory('Symbol')).deploy('ETHUSD-5000-P')
        symbolImplementationOptionETHUSD = await (await ethers.getContractFactory('SymbolImplementationOption')).deploy(
            symbolManager.address, oracleManager.address,
            ['ETHUSD-5000-P', 'ETHUSD', 'VOL-ETHUSD'],
            [bb(0.001), bb(0.04), bb(5000), bb(0.02), 86400, bb(0.01), bb(0.01), bb(0.1), bb(0.05), bb(0.01), 3600],
            [false, false ]
        )
        symbolOptionETHUSD.setImplementation(symbolImplementationOptionETHUSD.address)
        symbolOptionETHUSD = await ethers.getContractAt('SymbolImplementationOption', symbolOptionETHUSD.address)

        await symbolManager.addSymbol(symbolBTCUSD.address)
        await symbolManager.addSymbol(symbolETHUSD.address)
        await symbolManager.addSymbol(symbolOptionBTCUSD.address)
        await symbolManager.addSymbol(symbolOptionETHUSD.address)

        // market
        await pool.addMarket(vCAKE.address)
    })

    it('Test', async function () {
        await busd.mint(accounts[1].address, bb(1000000))
        await busd.connect(accounts[1]).approve(pool.address, MAX)
        await pool.connect(accounts[1]).addLiquidity(busd.address, bb(1000000))

        await pool.connect(accounts[2]).addMargin(ZERO_ADDRESS, 0, {value: bb(10)})
        await pool.connect(accounts[2]).trade('BTCUSD-60000-C', bb(1))

        await pool.connect(accounts[1]).removeLiquidity(busd.address, bb(10000))
    })
})
