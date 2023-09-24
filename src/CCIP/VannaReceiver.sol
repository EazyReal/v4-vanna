// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {IDynamicFeeManager} from "@uniswap/v4-core/contracts/interfaces/IDynamicFeeManager.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {FeeLibrary} from "@uniswap/v4-core/contracts/libraries/FeeLibrary.sol";
import {BaseHook} from "v4-periphery/BaseHook.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract Vanna is BaseHook, IDynamicFeeManager, CCIPReceiver {
    using FeeLibrary for uint24;

    error MustUseDynamicFee();

    bool private initialized;
    uint32 deployTimestamp;
    uint24 fee;

    constructor(address router) CCIPReceiver(router) {}

    function initialize(VolatilityOracle _volatilityOracle) public {
        require(!initialized, "Already initialized");
        initialized = true;
        volatilityOracle = _volatilityOracle;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal virtual override {
        (_fee) = abi.decode(message.data, (uint256));
        fee = uint24(_fee);
    }

    function getFee(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external view returns (uint24) {
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
