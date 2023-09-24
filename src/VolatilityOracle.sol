// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StringToInt {
    function stringToInt(
        string memory str,
        uint8 precision
    ) public pure returns (uint256) {
        // Convert the string to an integer by removing the decimal point and parsing it
        bytes memory strBytes = bytes(str);
        uint256 intValue = 0;
        bool decimalOccured = false;
        uint256 afterDecimal = 0;

        for (uint i = 0; i < strBytes.length; i++) {
            uint8 charCode = uint8(strBytes[i]);
            if (charCode >= 48 && charCode <= 57) {
                intValue = intValue * 10 + (charCode - 48);
                if (decimalOccured) {
                    afterDecimal += 1;
                }
            } else if (charCode == 46) {
                decimalOccured = true;
            }
        }

        // Apply the desired precision
        while (afterDecimal > precision) {
            intValue /= 10;
            afterDecimal -= 1;
        }

        while (afterDecimal < precision) {
            intValue *= 10;
            afterDecimal += 1;
        }

        return intValue;
    }
}

contract InferCallContract {
    function inferCall(
        string calldata modelName,
        string calldata inputData
    ) public returns (bytes32) {
        bytes32[2] memory output;
        bytes memory args = abi.encodePacked(modelName, "-", inputData);
        assembly {
            if iszero(
                staticcall(
                    not(0),
                    0x100,
                    add(args, 32),
                    mload(args),
                    output,
                    12
                )
            ) {
                revert(0, 0)
            }
        }
        return output[0];
    }
}

/**
    This smart contract demo the ability to use ML/AI inference directly on-chain using NATIVE SMART CONTRACT CAll
 */

contract VolatilityOracle is InferCallContract, StringToInt {
    uint256 volatility;

    constructor() {
        volatility = 50000;
    }

    function setVolatility(
        string calldata modelName,
        string calldata inputData
    ) public {
        volatility = stringToInt(
            string(abi.encodePacked(inferCall(modelName, inputData))),
            6
        );
    }

    function getVolatility() public view returns (uint256) {
        return volatility;
    }
}
