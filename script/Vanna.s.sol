// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {IPoolManager, PoolKey, Currency} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {FeeLibrary} from "@uniswap/v4-core/contracts/libraries/FeeLibrary.sol";
import {PoolModifyPositionTest} from "@uniswap/v4-core/contracts/test/PoolModifyPositionTest.sol";
import {PoolSwapTest} from "@uniswap/v4-core/contracts/test/PoolSwapTest.sol";
import {PoolDonateTest} from "@uniswap/v4-core/contracts/test/PoolDonateTest.sol";
import {Vanna} from "../src/Vanna.sol";
import {USDC} from "../src/USDC.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {VolatilityOracle} from "../src/VolatilityOracle.sol";
import {VannaFactory} from "../src/VannaFactory.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";

/// @notice Forge script for deploying v4 & hooks to **anvil**
/// @dev This script only works on an anvil RPC because v4 exceeds bytecode limits
contract VannaScript is Script {
    address constant CREATE2_DEPLOYER =
        address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        PoolManager poolManager = new PoolManager(500000);
        VolatilityOracle volatilityOracle = new VolatilityOracle();
        VannaFactory factory = new VannaFactory();
        PoolModifyPositionTest modifyPositionRouter = new PoolModifyPositionTest(
                IPoolManager(address(poolManager))
            );
        PoolSwapTest swapRouter = new PoolSwapTest(
            IPoolManager(address(poolManager))
        );
        vm.stopBroadcast();

        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG);

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(factory),
            flags,
            1000,
            type(Vanna).creationCode,
            abi.encode(address(poolManager))
        );

        // Deploy the hook using CREATE2
        vm.broadcast();
        Vanna vanna = Vanna(
            factory.deploy(volatilityOracle, poolManager, salt)
        );
        require(
            address(vanna) == hookAddress,
            "VannaScript: hook address mismatch"
        );
        console.logAddress(address(vanna));

        // deploy coins
        vm.broadcast();
        USDC usdc = new USDC();
        // uint24 dynamicFee = FeeLibrary.DYNAMIC_FEE_FLAG;
        uint160 sqrtPriceX96 = 1985562219192948852868261831073634;
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(usdc)),
            fee: FeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(vanna)
        });
        vm.broadcast();
        usdc.approve(address(modifyPositionRouter), 10000000000000 * 10 ** 6);

        vm.broadcast();
        usdc.approve(address(swapRouter), 10000000000000 * 10 ** 6);

        vm.broadcast();
        poolManager.initialize(key, sqrtPriceX96, "");
        vm.broadcast();
        modifyPositionRouter.modifyPosition{value: 2000000000 ether}(
            key,
            IPoolManager.ModifyPositionParams({
                tickLower: TickMath.minUsableTick(60),
                tickUpper: TickMath.maxUsableTick(60),
                liquidityDelta: 100
            })
        );
        // Additional helpers for interacting with the pool
        vm.startBroadcast();
        new PoolDonateTest(IPoolManager(address(poolManager)));
        vm.stopBroadcast();
    }
}
