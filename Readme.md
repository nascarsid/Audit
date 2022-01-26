VIZVA MARKETPLACE SMARTCONTRACTS
================================

This repository contains the smartcontracts developed by Boolien for Vizva Marketplace.

### prerequisite: `node`, `npm`, `truffle`

Deployment
---
***

* ### Create an .env file with following data.

```.env

ETHERSCAN_API_KEY =
DEVELOPMENT_MNEMONIC =
INFURA_SECRET =
INFURA_ID =
```

* ### Deploy to the network.

```BASH
truffle migrate --network rinkeby
```

* ### Verify source code.

```BASH
truffle run verify Vizva721 Vizva721Proxy VizvaProxyAdmin VizvaMarket_V1 VizvaMarketProxy --network rinkeby
```

#### `Note: If you wish to change network, Please add network configuration in truffle.config.`


Test
---
***

* ### Clone this repository.

```BASH
git clone https://github.com/nascarsid/Boolien-Smart-Contracts.git
```

* ### Install node packages.

```BASH
npm install
```

* ### Copy WETH.sol to contract directory.

```BASH
cp ./referenceCode/WETH.sol ./contracts/
```
`This step is only required for the test environment.`
* ### Run Test.

```BASH
truffle test
```