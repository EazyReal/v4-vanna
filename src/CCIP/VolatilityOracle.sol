// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

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

contract VolatilityOracle is InferCallContract, StringToInt, CCIPReceiver {
    uint256 volatility;
    enum PayFeesIn {
        Native,
        LINK
    }
    address immutable i_router;
    address immutable i_link;
    mapping(string => string) public hookContracts;
    event MessageSent(bytes32 messageId);

    constructor(address router, address link) {
        i_router = router;
        i_link = link;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
    }

    receive() external payable {}

    function setVolatility(
        string[] memory _tokenUris,
        uint64[] memory destinationChainSelectors,
        address[] memory _hookContracts,
        PayFeesIn payFeesIn,
        string calldata modelName,
        string calldata inputData
    ) public {
        volatility = stringToInt(
            string(abi.encodePacked(inferCall(modelName, inputData))),
            6
        );
        for (uint256 i = 1; i < _hookContracts.length; i++) {
            bytes memory payload = abi.encode(volatility);
            uint64 destinationChainSelector = destinationChainSelectors[i - 1];
            address hoockContract = _hookContracts[i - 1];
            Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
                receiver: abi.encode(hoockContract),
                data: abi.encodeWithSignature(string(payload), msg.sender),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: "",
                feeToken: payFeesIn == PayFeesIn.LINK ? i_link : address(0)
            });

            uint256 fee = IRouterClient(i_router).getFee(
                destinationChainSelector,
                message
            );

            bytes32 messageId;

            if (payFeesIn == PayFeesIn.LINK) {
                // LinkTokenInterface(i_link).approve(i_router, fee);
                messageId = IRouterClient(i_router).ccipSend(
                    destinationChainSelector,
                    message
                );
            } else {
                messageId = IRouterClient(i_router).ccipSend{value: fee}(
                    destinationChainSelector,
                    message
                );
            }
            emit MessageSent(messageId);
        }
    }

    function getVolatility() public view returns (uint256) {
        return volatility;
    }
}
