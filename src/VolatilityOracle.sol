pragma solidity >=0.8.20;

// contract InferCallContract {
//     function inferCall(
//         string calldata modelName,
//         string calldata inputData
//     ) public returns (bytes32) {
//         bytes32[2] memory output;
//         bytes memory args = abi.encodePacked(modelName, "-", inputData);
//         assembly {
//             if iszero(
//                 staticcall(
//                     not(0),
//                     0x100,
//                     add(args, 32),
//                     mload(args),
//                     output,
//                     12
//                 )
//             ) {
//                 revert(0, 0)
//             }
//         }
//         return output[0];
//     }
// }

/**
    This smart contract demo the ability to use ML/AI inference directly on-chain using NATIVE SMART CONTRACT CAll
 */
contract VolatilityOracle {
    uint256 volatility;

    function setVolatility() public {
        volatility = 20000; // 1e6 = 100%
    }

    function getVolatility() public view returns (uint256) {
        return volatility;
    }
}
