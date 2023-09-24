// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {BaseHook} from "v4-periphery/BaseHook.sol";
import {FullMath} from "@uniswap/v4-core/contracts/libraries/FullMath.sol";

import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {PoolId} from "@uniswap/v4-core/contracts/libraries/PoolId.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {PoolModifyPositionTest} from "@uniswap/v4-core/contracts/test/PoolModifyPositionTest.sol";


contract TestHook is BaseHook {
    using PoolId for IPoolManager.PoolKey;
    uint256 public swapCount;
    uint256 public OutofRange;
    int24 public UpperBound;
    int24 public LowerBound;
    bytes internal constant ZERO_BYTES = bytes(""); 
    // PoolModifyPositionTest modifyPositionRouter;
    error ZeroLiquidity();

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
            beforeInitialize: false,
            afterInitialize: false,
            beforeModifyPosition: false,
            afterModifyPosition: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
    }

    function afterSwap(
        address,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta
    )
        external
        override
        returns (bytes4)
    {
        swapCount++;
        bytes32 poolId = key.toId();
        (uint160 sqrtPriceX96, int24 tick, , , ,
            // uint8 protocolSwapFee,
            // uint8 protocolWithdrawFee,
            // uint8 hookSwapFee,
            // uint8 hookWithdrawFee
        ) = poolManager.getSlot0(poolId);
        uint160 LowerPrice = 2240910838991445679564910493696; // ~ 1:1
        if (tick < LowerBound) {
            OutofRange=1; // close the position here
        }
        if (tick > UpperBound) {
            OutofRange=2; // close the position here
        }
        return BaseHook.afterSwap.selector;
    }

    function place(PoolModifyPositionTest modifyPositionRouter, IPoolManager.PoolKey memory key, int24 TickLower, int24 TickUpper, int256 liquidity)
        external
        onlyValidPools(key.hooks)
    {  
    
        bytes32 poolId = key.toId();
        (uint160 sqrtPriceX96, int24 tick, , , ,
            // uint8 protocolSwapFee,
            // uint8 protocolWithdrawFee,
            // uint8 hookSwapFee,
            // uint8 hookWithdrawFee
        ) = poolManager.getSlot0(poolId);
        // modifyPositionRouter.modifyPosition(key, IPoolManager.ModifyPositionParams(TickLower, TickUpper, int256(liquidity)));
        LowerBound=TickLower;
        UpperBound=TickUpper;
        OutofRange=0;
    }

    function get_liquidity_xy(uint160 sp,uint160 sa,uint160 sb, uint128 Value ) public returns (uint256 x,uint256 y)  { //find_max_x
        uint256 numerator1=uint256(Value) << 96;
        uint256 dividorFirst=FullMath.mulDiv(uint256(sp-sa),uint256(sb),uint256(sb-sp));
        uint256 dividorSecond=FullMath.mulDiv(numerator1,1<<96,(dividorFirst+sp))/sp;
        x=dividorSecond;
        y=uint256(Value)-FullMath.mulDiv(uint256(sp),uint256(sp),2**96)*x/2**96;
        return (x,y);
        // return x = Value*2**96/((sp-sa)*sp*sb/(sb-sp)+sp*sp);
    }
    function get_liquidity(uint160 sp, uint160 sa, uint160 sb, uint256 x,uint256 y) public returns (uint256 liquidity)  { //find_max_x
        uint256 liquidity0=FullMath.mulDiv(uint256(sp),uint256(sb),uint256(sb-sp))*x >> 96;
        uint256 liquidity1=FullMath.mulDiv(y, 1<< 96,uint256(sp-sa)) ;
        liquidity0<liquidity1 ?  liquidity=liquidity0 :  liquidity= liquidity1;
        return liquidity;
    }

    function calculate_hedge_short(uint160 sp, uint160 sa, uint160 sb, uint256 liquidity) public returns (uint256 x1,uint256 y1) {
        uint256 amountxLower=FullMath.mulDiv(FullMath.mulDiv(liquidity,1<<96,uint256(sa)),uint256(sb-sa),uint256(sb));
        x1=FullMath.mulDiv(FullMath.mulDiv(amountxLower,sa,1<<96),sa,1<<96);
        uint256 amountyUpper=FullMath.mulDiv(liquidity,sb-sa,1<<96);
        y1=amountyUpper;
        return (x1, y1);
    }
}
