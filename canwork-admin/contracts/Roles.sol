pragma solidity ^0.4.21;


/**
 * @title Roles
 * @author Francisco Giordano (@frangio)
 * @dev Library for managing addresses assigned to a Role.
 *      See RBAC.sol for example usage.
 */
library Roles {
  struct BearerRecord {
    uint256 index;
    bool isActive;
  }

  struct Role {
    address[] indexes;
    mapping (address => BearerRecord) bearer;
  }

  /**
   * @dev give an address access to this role
   */
  function add(Role storage role, address addr)
    internal
  {
    BearerRecord storage record = role.bearer[addr];

    if (record.index == 0 && record.isActive == false) {
      record.index = role.indexes.length - 1;
      role.indexes.push(addr);
    } 

    record.isActive = true;
  }

  /**
   * @dev remove an address' access to this role
   */
  function remove(Role storage role, address addr)
    internal
  {
    role.bearer[addr].isActive = false;
  }

  /**
   * @dev check if an address has this role
   * // reverts
   */
  function check(Role storage role, address addr)
    view
    internal
  {
    require(has(role, addr));
  }

  /**
   * @dev check if an address has this role
   * @return bool
   */
  function has(Role storage role, address addr)
    view
    internal
    returns (bool)
  {
    return role.bearer[addr].isActive;
  }

  function size(Role storage role) 
  view 
  internal 
  returns (uint256) 
  {
    return role.indexes.length;
  }

  function get(Role storage role, uint256 index) internal view returns (address,bool) {
    address addr = role.indexes[index];
    return (addr, role.bearer[addr].isActive);
  }
}
