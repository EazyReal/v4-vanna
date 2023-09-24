// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {IDynamicFeeManager} from "@uniswap/v4-core/contracts/interfaces/IDynamicFeeManager.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {FeeLibrary} from "@uniswap/v4-core/contracts/libraries/FeeLibrary.sol";
import {BaseHook} from "v4-periphery/BaseHook.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {VolatilityOracle} from "../src/VolatilityOracle.sol";

contract Vanna is BaseHook, IDynamicFeeManager {
    using FeeLibrary for uint24;

    error MustUseDynamicFee();

    bool private initialized;
    uint32 deployTimestamp;
    VolatilityOracle volatilityOracle;

    function initialize(VolatilityOracle _volatilityOracle) public {
        require(!initialized, "Already initialized");
        initialized = true;
        volatilityOracle = _volatilityOracle;
    }

    function getFee(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external view returns (uint24) {
        require(initialized, "Not initialized");
        uint24 fee = uint24(volatilityOracle.getVolatility());
        return fee; // 1e6 is 100%
    }

    /// @dev For mocking
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp);
    }

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        deployTimestamp = _blockTimestamp();
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return
            Hooks.Calls({
                beforeInitialize: true,
                afterInitialize: false,
                beforeModifyPosition: false,
                afterModifyPosition: false,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false
            });
    }

    function beforeInitialize(
        address,
        PoolKey calldata key,
        uint160,
        bytes calldata
    ) external pure override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return Vanna.beforeInitialize.selector;
    }
}
