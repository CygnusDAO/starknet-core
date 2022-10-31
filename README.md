# Cygnus Factory contract on Starknet

![image](https://user-images.githubusercontent.com/97303883/191099232-7a3ea966-3e44-43cc-b2e3-5e83b725f9fb.png)

# Deployed and tested on Alpha-Goerli:

<p align="left">
Factory: https://goerli.voyager.online/contract/0x02e5e604b8693423843b009f6d6d7164c5ff3e190ed54875d396d068b0e4fb2b

Borrow Orbiter: https://goerli.voyager.online/contract/0x00f78fdf2a501117fe0111daaedf7a1f255ed7263e10c8a07deb8550f5027d67

Collateral Orbiter: https://goerli.voyager.online/contract/0x00916266918bd485b5c3bc5464aa7d614e1dbaf4d68fbe75b5b05e565372b37a

Borrowable: https://goerli.voyager.online/contract/0x7fc7944fd5179e10bc607aa97cf554785eef090e9c0a7749807430d0ce006b1

Collateral: https://goerli.voyager.online/contract/0x0105d3c64059e236fc85a2c6279ea7c48d654574b1b35769ed3fc9a8b9424663
</p>

Example of leverage transaction: https://testnet.starkscan.co/tx/0x0797eeee4d14bc26b203288d8bc21e9fc56955d9d4fedca41f70afb6fdf06839#overview

# Cygnus Finance

Cygnus is a stablecoin lending protocol. It is a non-custodial liquidity market protocol, where users can participate as lenders by supplying stablecoins or as borrowers by supplying their LP Tokens. Each lending pool is connected to a DEX (Jediswap, Sithswap, etc.), as such we follow the factory pattern to deploy to all the dexes possible on Starknet.

The factory contract makes use of 2 deployer contracts called "Orbiters" which are in charge of deploying a borrowable contract (for stablecoins) and a collateral contract (for LP Tokens), making 1 lending pool. This repository holds 3 main contracts:

1. `giza_power_plant` - The factory contract
<br />

2. `albireo_orbiter` - The borrow contract deployer
<br />

3. `deneb_orbiter.cairo` - The collateral contract deployer

<br />
<p align="center">
<img src="https://user-images.githubusercontent.com/97303883/190871738-29fa7ef3-2090-4478-93ef-279eff1121b3.svg" width=40% />
</p>

