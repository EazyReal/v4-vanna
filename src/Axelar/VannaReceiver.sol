// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "../contracts/interfaces/IPoolManager.sol";
import {IDynamicFeeManager} from "../contracts/interfaces/IDynamicFeeManager.sol";
import {Hooks} from "../contracts/libraries/Hooks.sol";
import {FeeLibrary} from "../contracts/libraries/FeeLibrary.sol";
import {BaseHook} from "../BaseHook.sol";
import {PoolKey} from "../contracts/types/PoolKey.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

contract Vanna is BaseHook, IDynamicFeeManager, AxelarExecutable {
    using FeeLibrary for uint24;
    IAxelarGasService public immutable gasService;
    error MustUseDynamicFee();

    bool private initialized;
    uint32 deployTimestamp;
    uint24 public fee;

    constructor(
        address gateway_,
        address gasReceiver,
        IPoolManager _poolManager
    ) AxelarExecutable(gateway_) BaseHook(_poolManager) {
        gasService = IAxelarGasService(gasReceiver);
        deployTimestamp = _blockTimestamp();
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

    function _execute(
        string calldata sourceChain_,
        string calldata sourceAddress_,
        bytes calldata payload_
    ) internal override {
        uint256 _fee;
        (_fee) = abi.decode(payload_, (uint256));
        fee = uint24(_fee);
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
