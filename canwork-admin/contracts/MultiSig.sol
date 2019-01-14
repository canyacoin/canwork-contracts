pragma solidity 0.4.24;


contract MultiSig {
  
  struct Signature {
    address[] signersIndex;
    mapping(address => bool) signers;
    uint8 count;
  }

  mapping(bytes32 => Signature) signedItems;

  event SignatureAdded(address indexed signer, bytes32 id);

  function addSig(address signer, bytes32 id) public returns (uint8) {
    require(signer != address(0));
    require(signedItems[id].signers[signer] != true);    

    signedItems[id].count += 1;
    signedItems[id].signersIndex.push(signer);
    signedItems[id].signers[signer] = true;

    emit SignatureAdded(signer, id);

    return signedItems[id].count;
  }

  function getSignersCount(bytes32 id) public view returns (uint8) {
    return signedItems[id].count;
  }

  function getSigner(bytes32 id, uint index) public view returns (address,bool) {    
    address signer = signedItems[id].signersIndex[index];
    return (signer, signedItems[id].signers[signer]);
  }

  function resetSignature(bytes32 id) public returns (bool) {
    signedItems[id].count = 0;
    for (uint i = 0; i < signedItems[id].signersIndex.length; i++) {
      address signer = signedItems[id].signersIndex[i];      
      signedItems[id].signers[signer] = false;
    }    

    return true;
  }
  
}