pragma solidity 0.4.24;

// import "openzeppelin-zos/contracts/token/ERC20/ERC20.sol";
// import "zos-lib/contracts/migrations/Migratable.sol";
import "./Migratable.sol";
import "./RBAC.sol";
import "./MultiSig.sol";
import "./Bytes32Utils.sol";
import "./Debugable.sol";

contract CanWorkAdmin is MultiSig, RBAC, Migratable, Debugable {
  using Bytes32Utils for bytes32;

  string public constant ROLE_OWNER = "owner";
  string public constant ROLE_ADMIN = "admin";  

  function initialize(address initialOwner1, address initialOwner2, address initialOwner3) 
  public 
  isInitializer("CanWorkAdmin", "0.1.2")
  {
    require(initialOwner1 != address(0) && initialOwner2 != address(0) && initialOwner3 != address(0));
    
    addRole(initialOwner1, ROLE_OWNER);
    addRole(initialOwner2, ROLE_OWNER);
    addRole(initialOwner3, ROLE_OWNER);
  } 

  function addOwner(address _owner) 
  public 
  onlyRole(ROLE_OWNER) 
  returns (bool)
  {
    require(_owner != address(0));
    require(!hasRole(_owner, ROLE_OWNER));

    bytes32 uniqueId = keccak256(abi.encodePacked(address(this), _owner, "addOwner"));

    if (getSignersCount(uniqueId) < 2) {
      addSig(msg.sender, uniqueId);
      return false;
    }

    addSig(msg.sender, uniqueId);

    addRole(_owner, ROLE_OWNER);

    resetSignature(uniqueId);
    
    return true;
  }

  function removeOwner(address _owner) 
  public 
  onlyRole(ROLE_OWNER)
  returns (bool)
  {
    require(_owner != address(0));
    require(hasRole(_owner, ROLE_OWNER));

    bytes32 uniqueId = keccak256(abi.encodePacked(address(this), _owner, "removeOwner"));

    if (getSignersCount(uniqueId) < 2) {
      addSig(msg.sender, uniqueId);
      return false;
    }

    addSig(msg.sender, uniqueId);

    resetSignature(uniqueId);

    removeRole(_owner, ROLE_OWNER);
    
    return true;
  }  

  function addAdmin(address _admin) 
  public 
  onlyRole(ROLE_OWNER)
  returns (bool)
  {
    require(_admin != address(0));
    require(!hasRole(_admin, ROLE_ADMIN));

    addRole(_admin, ROLE_ADMIN);
    
    return true;
  }

  function removeAdmin(address _admin) 
  public 
  onlyRole(ROLE_OWNER) 
  returns (bool)
  {
    require(_admin != address(0));
    require(hasRole(_admin, ROLE_ADMIN));

    removeRole(_admin, ROLE_ADMIN);
    
    return true;
  }    

  function getRoleMembersCount(bytes32 roleName)
  public 
  view 
  returns (uint256)
  {
    return size(roleName.bytes32ToStr());
  }

  function getRoleMember(bytes32 roleName, uint256 index) 
  public 
  view 
  returns (address,bool)
  {
    return get(roleName.bytes32ToStr(), index);
  }  

  function getOperationSignersCount(bytes32 operation, address _owner) 
  public 
  view 
  returns(uint)
  {   
    bytes32 uniqueId = keccak256(abi.encodePacked(address(this), _owner, operation.bytes32ToStr()));
    return getSignersCount(uniqueId);
  }

  function getOperationSigner(bytes32 operation, address _owner, uint index) 
  public 
  view 
  returns (address,bool)
  {
    bytes32 uniqueId = keccak256(abi.encodePacked(address(this), _owner, operation.bytes32ToStr()));
    return getSigner(uniqueId, index);    
  }
  
}