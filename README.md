Automated market makers (AMMs) provide liquidity for trading transactions, however suffered from impermanent loss (IL) for a long time. As the AMM strategies develop from constant product, customized curve, to concentrated liquidity, the effects of impermanent loss become remarkably severe. Specifically, impermanent loss occurs for market makers when the market price deviates from the initial providing price, since the updated liquidity value (without calculation swap fee income) is always lower than the value of the holding assets and accounted as loss. To reduce the risk of the impermanent loss for liquidity providers becomes practically important. Thus, UniHedge is focusing on hedge liquidity exposure on the basis of Uniswap V3, V4 Hook, and lending protocols.

# Installation
Test in foundry (recommend using WSL or a unix based OS)
```
curl -L https://foundry.paradigm.xyz | bash
source /home/ubuntu/.bashrc

foundryup

git init
git clone https://github.com/jamesbachini/Uniswap-v4-Tests.git
forge install https://github.com/Uniswap/v4-core --no-commit
forge install openzeppelin/openzeppelin-contracts --no-commit
forge install marktoda/forge-gas-snapshot --no-commit

forge test -vv --via-ir
