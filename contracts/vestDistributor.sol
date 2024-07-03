// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

library Strings {
  bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

  /**
   * @dev Converts a `uint256` to its ASCII `string` decimal representation.
   */
  function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT licence
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

    if (value == 0) {
      return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
      digits++;
      temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
      value /= 10;
    }
    return string(buffer);
  }
}

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
  /**
   * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
   * defined by `root`. For this, a `proof` must be provided, containing
   * sibling hashes on the branch from the leaf to the root of the tree. Each
   * pair of leaves and each pair of pre-images are assumed to be sorted.
   */
  function verify(
    bytes32[] memory proof,
    bytes32 root,
    bytes32 leaf
  ) internal pure returns (bool) {
    bytes32 computedHash = leaf;

    for (uint256 i = 0; i < proof.length; i++) {
      bytes32 proofElement = proof[i];

      if (computedHash <= proofElement) {
        // Hash(current computed hash + current element of the proof)
        computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
      } else {
        // Hash(current element of the proof + current computed hash)
        computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
      }
    }

    // Check if the computed hash (root) is equal to the provided root
    return computedHash == root;
  }
}
abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }
}

contract Ownable is Context {
  address private _owner;
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  constructor() {
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
  }

  function owner() public view returns (address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(_owner == _msgSender(), "Ownable: caller is not the owner");
    _;
  }

  function renounceOwnership() external virtual onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }

  function transferOwnership(address newOwner) external virtual onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

contract filmChainVestDistributor is Ownable {
  uint256 internal constant ONE = 10 ** 18;

  using Strings for uint256;

  address public filmChainToken;

  mapping(bytes32 => bool) claimed;

  bytes32 merkleRoot =
    0x7cabfcb831bbc2a9e5f71628c2a01d04b27c1c6219f66220c9bcbf24dc142029;

  constructor(address _filmChainToken) {
    filmChainToken = _filmChainToken;
  }

  function setFilmachain(address _filmChainToken) external onlyOwner {
    filmChainToken = _filmChainToken;
  }

  function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function addressToBytes(address a) internal pure returns (bytes memory b) {
    assembly {
      let m := mload(0x40)
      a := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
      mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
      mstore(0x40, add(m, 52))
      b := m
    }
  }

  function strToUint(string memory _str) public pure returns (uint256 res) {
    for (uint256 i = 0; i < bytes(_str).length; i++) {
      if (
        (uint8(bytes(_str)[i]) - 48) < 0 || (uint8(bytes(_str)[i]) - 48) > 9
      ) {
        return 0;
      }
      res += (uint8(bytes(_str)[i]) - 48) * 10 ** (bytes(_str).length - i - 1);
    }

    return res;
  }

  function uintToBigEndBytesWithoutByteType(
    uint x
  ) internal pure returns (uint) {
    return (x / 10) * 6 + x;
  }

  function bytesToUintAtIndex(
    bytes memory _bytes,
    uint _index
  ) internal pure returns (uint256) {
    uint convValue = uint256(uint8(_bytes[_index]));
    uint256 _value = (convValue / 16) * 10;
    uint i = 0;
    uint image = uintToBigEndBytesWithoutByteType(_value);
    while (image != convValue && i <= 10) {
      _value++;
      image = uintToBigEndBytesWithoutByteType(_value);
      i++;
    }
    if (image == convValue) {
      return _value;
    } else {
      return 0;
    }
  }

  function bytesToUint(bytes memory _bytes) internal pure returns (uint) {
    uint byteAtInd = bytesToUintAtIndex(_bytes, 0);
    if (byteAtInd == 0) {
      return 0;
    }
    string memory _str = byteAtInd.toString();
    for (uint i = 1; i < _bytes.length; i++) {
      byteAtInd = bytesToUintAtIndex(_bytes, i);
      if (byteAtInd == 0) {
        return 0;
      }
      _str = string(abi.encodePacked(_str, byteAtInd.toString()));
    }
    return strToUint(_str);
  }

  // function verifyClaimBytes(address _account, bytes memory _amountToClaim, bytes32[] calldata _merkleProof)
  //     public view
  //     returns (bool)
  // {
  //     bytes32 node = keccak256(abi.encodePacked(addressToBytes(_account), _amountToClaim));
  //     return MerkleProof.verify(_merkleProof, merkleRoot, node);
  // }

  function _verifyClaimBytes(
    address _account,
    bytes memory _amountToClaim,
    bytes32[] calldata _merkleProof
  ) internal returns (bool) {
    bytes32 node = keccak256(
      abi.encodePacked(addressToBytes(_account), _amountToClaim)
    );
    require(!claimed[node], "claimed");
    claimed[node] = true;
    return MerkleProof.verify(_merkleProof, merkleRoot, node);
  }

  function claim(
    bytes memory _amountToClaim,
    bytes32[] calldata _merkleProof
  ) external {
    require(
      _verifyClaimBytes(_msgSender(), _amountToClaim, _merkleProof),
      "not eligible for a claim"
    );
    FILMChainToken(filmChainToken).transferFrom(
      owner(),
      _msgSender(),
      bytesToUint(_amountToClaim) * ONE
    );
  }
}

interface FILMChainToken {
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool);
}
