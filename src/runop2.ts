// run a single op
// "yarn run runop [--network ...]"

import hre, { ethers, run } from 'hardhat'
import { AASigner, localUserOpSender, rpcUserOpSender } from './AASigner'
import { EntryPoint, InitializableAccountFactory, ChainlinkPaymaster, TestCoin } from '../typechain'
import '../test/aa.init'
import { providers } from 'ethers'
import { TransactionReceipt } from '@ethersproject/abstract-provider/src.ts/index';

// eslint-disable-next-line @typescript-eslint/no-floating-promises
(async () => {
  console.log('net=', hre.network.name)
  const aa_url = process.env.AA_URL

  //set aa_url as your bundler rpc url

  let entrypoint: EntryPoint
  let factory: InitializableAccountFactory
  let paymaster: ChainlinkPaymaster
  let tc: TestCoin

  const result = await run("deploy:initializableContracts", {})
  entrypoint = result['entrypoint']
  factory = result['factory']
  paymaster = result['paymaster']
  tc = result['tc']

  const [signer] = await ethers.getSigners()
  
  console.log('using eoa account address', signer.address)

  let sendUserOp

  if (aa_url != null) {
    const newprovider = new providers.JsonRpcProvider(aa_url)
    sendUserOp = rpcUserOpSender(newprovider, entrypoint.address)
    const supportedEntryPoints: string[] = await newprovider.send('eth_supportedEntryPoints', []).then(ret => ret.map(ethers.utils.getAddress))
    console.log('node supported EntryPoints=', supportedEntryPoints)
    if (!supportedEntryPoints.includes(entrypoint.address)) {
      console.error('ERROR: node', aa_url, 'does not support our EntryPoint')
    }
  } else { sendUserOp = localUserOpSender(entrypoint.address, signer) }

  // index is unique for an account (so same owner can have multiple accounts, with different index
  const index = parseInt(process.env.AA_INDEX ?? '0')
  console.log('using account index (AA_INDEX)', index)
  const aasigner = new AASigner(signer, entrypoint.address, sendUserOp, index)
  
  const aaAddress = await factory.getAddress(signer.address, index)
  console.log("using abstruct account address", aaAddress)
  //create account
  await factory.createAccount(signer.address, index)

  await aasigner.connectAccountAddress(aaAddress)

  await tc.mint();
  await tc.transfer(aaAddress, ethers.utils.parseEther('100'))

  console.log("eoa account test coin balance", ethers.utils.formatEther(await tc.balanceOf(signer.address)))

  const prebalance = await tc.balanceOf(aaAddress)
  console.log("abstruct account test coin balance", ethers.utils.formatEther(prebalance))
  
  await paymaster.deposit({value: ethers.utils.parseEther('10')})

  aasigner.setPaymster(paymaster.address)

  const ret1 = await tc.approve(signer.address, ethers.utils.parseEther('10000000000'))
  const rcpt2 = await ret1.wait()

  console.log("hash:", ret1.blockHash)
  console.log('2nd run:', await evInfo(rcpt2))
  
  const gasPaid = prebalance.sub(await tc.balanceOf(aaAddress))
  console.log("abstruct account paid", ethers.utils.formatEther(gasPaid))

  async function evInfo (rcpt: TransactionReceipt): Promise<any> {
    // TODO: checking only latest block...
    const block = rcpt.blockNumber
    const ev = await entrypoint.queryFilter(entrypoint.filters.UserOperationEvent(), block)
    // if (ev.length === 0) return {}
    return ev.map(event => {
      const { nonce, actualGasUsed } = event.args
      const gasUsed = rcpt.gasUsed.toNumber()
      return { nonce: nonce.toNumber(), gasPaid, gasUsed: gasUsed, diff: gasUsed - actualGasUsed.toNumber() }
    })
  }

})()
