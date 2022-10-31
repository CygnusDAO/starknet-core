# Cygnus Factory contract on Starknet

![image](https://user-images.githubusercontent.com/97303883/191099232-7a3ea966-3e44-43cc-b2e3-5e83b725f9fb.png)

# Deployed and tested on Alpha-Goerli:

<p align="left">
Factory: https://testnet.starkscan.co/contract/0x5e67e32b4c973979d3b5b7bd3d6586cb81c1ff68ac0a8720662d2e7820acc58

Borrow Orbiter: https://testnet.starkscan.co/contract/0x1c20147d22a5af4d4610590f02d3cc23ece238d276dd4e4bf1055c90d73f0c2

Collateral Orbiter: https://testnet.starkscan.co/contract/0x7993d549f970ba5dca9dbb1e871017f4aff301197797d2d49c585058c16d1ee

Borrowable: https://testnet.starkscan.co/contract/0x1e2a5c8a5c31caac0a471b2e9af73d895491b47162b61b0b298d141a9134146

Collateral: https://testnet.starkscan.co/contract/0x02dc069e14a94ceb2fe924fd1ba9bb574d31de02f1c382adf1d1514d38c9524d
</p>

Example of leverage transaction between borrowable and collateral: https://testnet.starkscan.co/tx/0x0797eeee4d14bc26b203288d8bc21e9fc56955d9d4fedca41f70afb6fdf06839#overview

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

