# Uniswap v4 Hedge Hook

A Uniswap v4 hook which creates an afterSwap hook to check if price is above or below hedge range. If so, withdraw the lp and close hedge position. 

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

forge test
```
