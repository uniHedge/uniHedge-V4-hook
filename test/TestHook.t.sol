// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {TestERC20} from "@uniswap/v4-core/contracts/test/TestERC20.sol";
import {IERC20Minimal} from "@uniswap/v4-core/contracts/interfaces/external/IERC20Minimal.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v4-core/contracts/libraries/FullMath.sol";
import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap/v4-core/contracts/libraries/PoolId.sol";
import {PoolModifyPositionTest} from "@uniswap/v4-core/contracts/test/PoolModifyPositionTest.sol";
import {PoolSwapTest} from "@uniswap/v4-core/contracts/test/PoolSwapTest.sol";
import {PoolDonateTest} from "@uniswap/v4-core/contracts/test/PoolDonateTest.sol";
import {Deployers} from "@uniswap/v4-core/test/foundry-tests/utils/Deployers.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/libraries/CurrencyLibrary.sol";
import {TestHook} from "../src/TestHook.sol";
import {TestImplementation} from "../src/implementation/TestImplementation.sol";


contract HookTest is Test, Deployers, GasSnapshot {
    using PoolId for IPoolManager.PoolKey;
    using CurrencyLibrary for Currency;

    TestHook testHook = TestHook(
        address(uint160(Hooks.AFTER_SWAP_FLAG))
    );
    PoolManager manager;
    PoolModifyPositionTest modifyPositionRouter;
    PoolSwapTest swapRouter;
    TestERC20 token0;
    TestERC20 token1;
    IPoolManager.PoolKey poolKey;
    bytes32 poolId;

    function setUp() public {
        token0 = new TestERC20(2**128);
        token1 = new TestERC20(2**128);
        manager = new PoolManager(500000);

        // testing environment requires our contract to override `validateHookAddress`
        // well do that via the Implementation contract to avoid deploying the override with the production contract
        TestImplementation impl = new TestImplementation(manager, testHook);
        (, bytes32[] memory writes) = vm.accesses(address(impl));
        vm.etch(address(testHook), address(impl).code);
        // for each storage key that was written during the hook implementation, copy the value over
        unchecked {
            for (uint256 i = 0; i < writes.length; i++) {
                bytes32 slot = writes[i];
                vm.store(address(testHook), slot, vm.load(address(impl), slot));
            }
        }

        // user parameter
        uint160 LowerPrice=2240910838991445679564910493696; // 800 in SqrtX96
        uint160 UpperPrice=2744544057300596215249920589824; // 1200 in SqrtX96
        uint160 CurrentPrice=2505414483750479251915866636288; // 1000 in SqrtX96
        uint128 UserInitValue=1e18;
        uint256 Leverage=2;
        
        // Create the pool
        poolKey = IPoolManager.PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 1, IHooks(testHook)); //tick space change to 1
        poolId = PoolId.toId(poolKey);
        manager.initialize(poolKey, CurrentPrice);


        
        // Tick calculation
        int24  TickLower= TickMath.getTickAtSqrtRatio(LowerPrice);
        int24  TickUpper= TickMath.getTickAtSqrtRatio(UpperPrice);
        int24  TickCurrent= TickMath.getTickAtSqrtRatio(CurrentPrice);

        emit log("******Liquidity provider known Variables******");
        emit log("The User portforlio:");
        emit log_uint(UserInitValue);
        emit log("Current sqrtPriceX96 and tick:");
        emit log_uint(CurrentPrice);
        emit log_int(TickCurrent);
        emit log("Lower bound in sqrtPriceX96 and tick:");
        emit log_uint(LowerPrice);
        emit log_int(TickLower);
        emit log("Upper bound in sqrtPriceX96 and tick:");
        emit log_uint(UpperPrice);
        emit log_int(TickUpper);
        emit log("");

        // calculate token0 and token1 amount if UserInitValue all for liquidity
        (uint256 token0amountV,uint256 token1amountV)=get_liquidity_xy(CurrentPrice,LowerPrice,UpperPrice, UserInitValue);
      
        // calculate the liquidity
        (uint256 liquidityV)=get_liquidity(CurrentPrice, LowerPrice,UpperPrice, token0amountV,token1amountV);
        
        // calculate the imploss during the range
        (uint256 ValueLower,uint256 ValueUpper)=calculate_hedge_short(CurrentPrice, LowerPrice, UpperPrice, liquidityV);

        // calculate the hedge position      
        uint256 ShortvalueV=(ValueUpper-ValueLower)/400*1000;

        // Proportionally share the UserInitValue to Lp and hedge position
        uint256 Shortvalue=FullMath.mulDiv(ShortvalueV,UserInitValue,ShortvalueV/Leverage+UserInitValue);
        uint256 LPvalue=UserInitValue-Shortvalue/Leverage;
        uint256 liquidity=FullMath.mulDiv(liquidityV,UserInitValue,ShortvalueV/Leverage+UserInitValue);
        uint256 token0amount=FullMath.mulDiv(token0amountV,UserInitValue,ShortvalueV/Leverage+UserInitValue);
        uint256 token1amount=FullMath.mulDiv(token1amountV,UserInitValue,ShortvalueV/Leverage+UserInitValue);


        emit log("******Hedging calculation results******");
        // uint160 testprice2= TickMath.getSqrtRatioAtTick(60);
        emit log(" The User portforlio:");
        emit log_uint(UserInitValue);
        emit log(" Amount of token0 provide for pool:");
        emit log_uint(token0amount);
        emit log(" Amount of token1 provide for pool:");
        emit log_uint(token1amount);
        emit log(" Value of liquidity:");
        emit log_uint(LPvalue);
        emit log(" Value of token1 short in lending:");
        emit log_uint(Shortvalue);
        emit log(" Leverage in lending:");
        emit log_uint(Leverage);
        emit log("");
        // emit log_uint(token1amountV);
        // emit log_uint(liquidityV);
        // emit log_uint(liquidity);
        // emit log_address(address(manager));
        // emit log_bytes32(poolId);
        // emit log_address(address(token0));
        // emit log_address(address(token1));

        // Helpers for interacting with the pool
        modifyPositionRouter = new PoolModifyPositionTest(IPoolManager(address(manager)));
        swapRouter = new PoolSwapTest(IPoolManager(address(manager)));


        // // Provide liquidity to the pool
        token0.approve(address(modifyPositionRouter), 100 ether);
        token1.approve(address(modifyPositionRouter), 100 ether);
        token0.mint(address(this), 100 ether);
        token1.mint(address(this), 100 ether);

        // Provide LP liquidity to the pool
         modifyPositionRouter.modifyPosition(poolKey, IPoolManager.ModifyPositionParams(TickLower, TickUpper, int256(liquidity)));
        // // Provide hedge position to aave **

        // Approve for swapping
        token0.approve(address(swapRouter), 100 ether);
        token1.approve(address(swapRouter), 100 ether);

        (uint160 sqrtPriceX96, int24 tick, , , ,
        // uint8 protocolSwapFee,
        // uint8 protocolWithdrawFee,
        // uint8 hookSwapFee,
        // uint8 hookWithdrawFee
        ) = manager.getSlot0(poolId);

        emit log("******   pool  condition   ******");
        emit log_uint(sqrtPriceX96);
        testHook.place(poolKey, TickLower, TickUpper, int256(liquidity));
        emit log("******   good   ******");
        
    }

    // function testHooks() public {
    //     assertEq(testHook.swapCount(), 0);
        
    //     for (int i=1; i<10 ; i++) {
    //         // Perform a test swap //
    //         IPoolManager.SwapParams memory params =
    //             IPoolManager.SwapParams({zeroForOne: true, amountSpecified: 1e13, sqrtPriceLimitX96: SQRT_RATIO_1_2});

    //         PoolSwapTest.TestSettings memory testSettings =
    //             PoolSwapTest.TestSettings({withdrawTokens: true, settleUsingTransfer: true});
            
    //         swapRouter.swap(
    //             poolKey,
    //             params,
    //             testSettings
    //         );
    //         (uint160 sqrtPriceX96, int24 tick, , , ,
    //         // uint8 protocolSwapFee,
    //         // uint8 protocolWithdrawFee,
    //         // uint8 hookSwapFee,
    //         // uint8 hookWithdrawFee
    //         ) = manager.getSlot0(poolId);

    //         emit log("******swap index:");
    //         emit log_int(i);
    //         emit log("price and tick after swap:");
    //         emit log_uint(sqrtPriceX96);
    //         emit log_int(tick);
    //     }
    //     // assertEq(testHook.swapCount(), 1);
    // }

   
    function get_liquidity_xy(uint160 sp,uint160 sa,uint160 sb, uint128 Value ) public returns (uint256 x,uint256 y)  { //find_max_x
        // FullMath.mul()
        // uint256 numerator1=uint256(sp-sa);
        // uint256 numerator2=uint256(sp-sa);
        // uint256 numerator1 = uint256(Value) << FixedPoint96.RESOLUTION;
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
