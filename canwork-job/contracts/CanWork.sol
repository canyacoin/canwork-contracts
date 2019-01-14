pragma solidity 0.4.24;

import "./CanWorkJob.sol";

contract CanWork is CanWorkJob {
    ERC20 canYaCoin;

    event OnEmeregencyTransfer(address indexed toAddress, uint256 balance);

    function initialize(ERC20 _token, CanWorkAdmin _canworkAdmin, address _dApp, address _priceOracle) 
    public 
    isInitializer("CanWork", "0.1.2") {
        require(_token != address(0) && _canworkAdmin != address(0) && _dApp != address(0), "Addresses must be valid");

        CanWorkJob.initialize(_token, _canworkAdmin, _dApp, _priceOracle);      

        canYaCoin = _token;        
    }
  
    function emergencyTransfer(address toAddress) 
    public     
    returns (bool) {
        require(toAddress != address(0), "Address must be valid");
        require(canworkAdmin.hasRole(msg.sender, ROLE_OWNER), "Must have Owner role");

        bytes32 uniqueId = keccak256(abi.encodePacked(address(this), toAddress, "emergencyTransfer"));

        if (canworkAdmin.getSignersCount(uniqueId) < 2) {
            canworkAdmin.addSig(msg.sender, uniqueId);
            return false;
        }

        canworkAdmin.addSig(msg.sender, uniqueId);

        canworkAdmin.resetSignature(uniqueId);

        uint256 balance = canYaCoin.balanceOf(address(this));
        canYaCoin.transfer(toAddress, balance);

        emit OnEmeregencyTransfer(toAddress, balance);

        return true;
    }

    function getEmergencyTransferSignersCount(address _toAddress)
    public 
    view 
    returns(uint)
    {   
        bytes32 uniqueId = keccak256(abi.encodePacked(address(this), _toAddress, "emergencyTransfer"));
        return canworkAdmin.getSignersCount(uniqueId);
    }    

    function getEmergencyTransferSigner(address _toAddress, uint index)
    public 
    view 
    returns (address,bool)
    {
        bytes32 uniqueId = keccak256(abi.encodePacked(address(this), _toAddress, "emergencyTransfer"));
        return canworkAdmin.getSigner(uniqueId, index);
    }  
  
}