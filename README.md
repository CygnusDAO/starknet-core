# Cygnus Factory contract on Starknet

![image](https://user-images.githubusercontent.com/97303883/191099232-7a3ea966-3e44-43cc-b2e3-5e83b725f9fb.png)

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

Deployed addresses on Alpha Goerli:
