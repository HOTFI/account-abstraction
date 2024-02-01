import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { task, types } from "hardhat/config"

task("deploy:initializableContracts", "Deploy hofi account factory")
    .setAction(async ({}, 
        { ethers, run }) =>{
    const provider = ethers.provider
    const network = await provider.getNetwork()
    // only deploy on local test network.
    if (network.chainId !== 31337 && network.chainId !== 1337) {
      return
    }

    const entrypoint = await(await ethers.getContractFactory('EntryPoint')).deploy()
    await entrypoint.deployed()
    console.log('==entrypoint addr=', entrypoint.address)
    
    const tc = await(await ethers.getContractFactory('TestCoin')).deploy()
    await tc.deployed()

    console.log('==TestCoin addr=', tc.address)
  
    const oracle = await(await ethers.getContractFactory('TestPriceFeed')).deploy()
    await oracle.deployed()
    console.log('==TestPriceFeed addr=', oracle.address)
  
  
    const factory = await(await ethers.getContractFactory('InitializableAccountFactory')).deploy(entrypoint.address)  
    await factory.deployed()
    console.log('==InitializableAccountFactory addr=', factory.address)
  
    const paymaster = await(await ethers.getContractFactory('ChainlinkPaymaster')).deploy(factory.address, entrypoint.address, tc.address, oracle.address)
    await paymaster.deployed()
    console.log('==ChainlinkPaymaster addr=', paymaster.address)
    
    await factory.init([tc.address], [paymaster.address])

    return {entrypoint,factory, paymaster, tc, oracle}
    });