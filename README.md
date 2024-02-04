Implementation of contracts for [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) account abstraction via alternative mempool.

# InitializableAccount
InitializableAccount allow the absctruct account facotory execute some constant operations when creating a contract acount.

In this simples, the abstruct account will approve token to the paymasters when they were created, in order to resolve the issue that they must have native token to pay the gas cost of approving.

- init
```bash
yarn && yarn hardhat compile
```

- submit abstruct account operation
```bash
yarn runop2
```

# Resources

[Vitalik's post on account abstraction without Ethereum protocol changes](https://medium.com/infinitism/erc-4337-account-abstraction-without-ethereum-protocol-changes-d75c9d94dc4a)

[Discord server](http://discord.gg/fbDyENb6Y9)

[Abstruct account reference implementation](https://github.com/eth-infinitism/account-abstraction)

[Bundler reference implementation](https://github.com/HOTFI/hotfi-bundler)

[Bundler specification test suite](https://github.com/eth-infinitism/bundler-spec-tests)
