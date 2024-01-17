// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {EIP712} from "solady/src/utils/EIP712.sol";

/// @notice ERC1271 with guards for same signer being used on multiple accounts
/// Based on Solady (https://github.com/vectorized/solady/blob/main/src/accounts/ERC1271.sol)
/// @author Wilson Cusack
abstract contract ERC1271 {
    bytes32 public immutable domainSeparator;
    bytes32 private constant _MESSAGE_TYPEHASH = keccak256("CoinbaseSmartAccountMessage(bytes32 messageHash)");

    constructor() {
        (string memory name, string memory version) = _domainNameAndVersion();
        domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) public view virtual returns (bytes4 result) {
        if (_validateSignature(replaySafeHash(hash), signature)) {
            // bytes4(keccak256("isValidSignature(bytes32,bytes)"))
            return 0x1626ba7e;
        }

        return 0xffffffff;
    }

    /// @dev Incase a signer is on multiple accounts, we expect all messages
    /// to be wrapped in an EIP 712 hash that includes the domain hash
    /// EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
    function replaySafeHash(bytes32 messageHash) public view virtual returns (bytes32) {
        return _eip712Hash(_hashStruct(messageHash));
    }

    /// @dev See: https://eips.ethereum.org/EIPS/eip-5267
    function eip712Domain()
        external
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        fields = hex"0f"; // `0b1111`.
        (name, version) = _domainNameAndVersion();
        chainId = block.chainid;
        verifyingContract = address(this);
        salt = salt; // `bytes32(0)`.
        extensions = extensions; // `new uint256[](0)`.
    }

    /// @dev encode(domainSeparator : 𝔹²⁵⁶, message : 𝕊) = "\x19\x01" ‖ domainSeparator ‖ hashStruct(message)
    /// https://eips.ethereum.org/EIPS/eip-712
    function _eip712Hash(bytes32 hashStruct) internal view virtual returns (bytes32 digest) {
        digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, hashStruct));
    }

    /// @dev hashStruct(s : 𝕊) = keccak256(typeHash ‖ encodeData(s))
    /// https://eips.ethereum.org/EIPS/eip-712
    function _hashStruct(bytes32 messageHash) internal view virtual returns (bytes32) {
        return keccak256(abi.encode(_MESSAGE_TYPEHASH, messageHash));
    }

    /// @dev Please override this function to return the domain name and version.
    function _domainNameAndVersion() internal view virtual returns (string memory name, string memory version);

    /// @dev Implement to vefify signature
    function _validateSignature(bytes32 message, bytes calldata signature) internal view virtual returns (bool);
}
