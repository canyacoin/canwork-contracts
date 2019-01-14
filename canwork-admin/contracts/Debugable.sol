pragma solidity 0.4.24;

contract Debugable {
  function getAddress() public view returns (address) { return address(this); }
  function getSender() public view returns (address) { return address(msg.sender); }
}