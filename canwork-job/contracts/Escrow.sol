pragma solidity 0.4.24;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Migratable.sol";

/**
 * @title ERC20 Bancor Price Oracle Interface
 */
contract ERC20BancorPriceOracle {
    function getTokenToDai(uint256 _tokenAmount) external view returns (uint256);
    function getDaiToToken(uint256 _daiAmount) external view returns (uint256);
}


contract Escrow is Migratable {
    using SafeMath for uint256;

    ERC20 internal escrowToken;
    uint256 internal escrowId = 0;
    address escrowDapp;    

    uint256 internal DAPP_PAYMENT_PERCENTAGE;  

    ERC20BancorPriceOracle public priceOracle;

    enum EscrowStatus {
        New,
        Completed,
        Cancelled
    }

    struct EscrowRecord {
        uint256 id;
        address client;
        address provider;
        uint256 amount;
        uint256 totalValueDai;
        EscrowStatus status;
        uint256 createdAt;
        uint256 closedAt;
        uint256 payoutAmount;
        uint256 paidToDappAmount;
        uint256 paidToProviderAmount;
        uint256 paidToClientAmount;
        uint256 paidToArbiterAmount;
    }

    mapping(uint256 => EscrowRecord) internal escrows;

    event OnInitialize(address indexed token, address indexed dApp, address priceOracle);
    event OnCreateEscrow(address indexed dapp, address indexed client, address indexed provider, uint256 amount, uint256 daiAmount);
    event OnCompleteEscrow(address indexed dapp, uint256 indexed escrowId);
    event OnCancelEscrowByProvider(address indexed dapp, uint256 indexed escrowId);
    event OnCancelEscrow(address indexed dapp, uint256 indexed escrowId, uint256 payToProviderAmount, address indexed arbiter, uint256 payToArbiterAmount);
    
    function initialize(ERC20 _token, address _dApp, address _priceOracle) 
    internal 
    isInitializer("Escrow", "0.1.3") {
        require(_token != address(0) && _dApp != address(0) && _priceOracle != address(0), "Must be valid addresses");
        
        escrowToken = _token;
        escrowDapp = _dApp;
        priceOracle = ERC20BancorPriceOracle(_priceOracle);
        DAPP_PAYMENT_PERCENTAGE = 1;

        emit OnInitialize(_token, _dApp, _priceOracle);
    }

    /**
     * @dev Initialise the escrow and store its details on chain
     * Calculates the DAI value equivalent of the deposited CAN tokens and stores this to hedge the escrow later
     * @param _client Address of the client
     * @param _provider Address of the provider
     * @param _amount total amount of CAN
     * @return id of the escrow
     */
    function createEscrow(address _client, address _provider, uint256 _amount) 
    internal 
    returns (uint256) {
        require(_client != address(0) && _provider != address(0) && _amount > 0, "Must be a valid addresses and non zero amounts");
        require(escrowToken.transferFrom(_client, address(this), _amount), "Client must have authorisation and balance to transfer CAN");

        uint256 daiValueInEscrow = priceOracle.getTokenToDai(_amount);
        require(daiValueInEscrow > 0, "Job value must be greater than 0 USD");

        uint256 id = ++escrowId;
        EscrowRecord storage escrow = escrows[id];
        escrow.id = id;
        escrow.client = _client;
        escrow.provider = _provider;
        escrow.amount = _amount;
        escrow.totalValueDai = daiValueInEscrow;
        escrow.createdAt = block.number;
        escrow.status = EscrowStatus.New;
        escrow.payoutAmount = 0;
        escrow.paidToProviderAmount = 0;
        escrow.paidToClientAmount = 0;
        escrow.paidToArbiterAmount = 0;

        emit OnCreateEscrow(escrowDapp, _client, _provider, _amount, daiValueInEscrow);

        return id;
    }

    /**
     * @dev Completes the escrow, calculating the amount of CAN to pay out based on the DAI value
     * Sends DAPP_PAYMENT_PERCENTAGE amount to the dapp, and the rest to the provider
     * @param _escrowId Id of the escrow to complete
     * @return bool success
     */
    function completeEscrow(uint256 _escrowId) 
    internal 
    returns (bool) {
        require(escrows[_escrowId].status == EscrowStatus.New, "Escrow status must be 'new'");
        require(escrows[_escrowId].client == msg.sender, "Transaction must be sent by the client");

        escrows[_escrowId].status = EscrowStatus.Completed;
        escrows[_escrowId].closedAt = block.number;

        escrows[_escrowId].payoutAmount = getTotalPayoutCAN(_escrowId);

        uint256 payToDappAmount = escrows[_escrowId].payoutAmount.mul(DAPP_PAYMENT_PERCENTAGE).div(100);
        if(payToDappAmount > 0){
            escrows[_escrowId].paidToDappAmount = payToDappAmount;
            require(escrowToken.transfer(escrowDapp, payToDappAmount), "Dapp must receive payment");
        }

        uint256 providerPayoutCan = escrows[_escrowId].payoutAmount.sub(payToDappAmount);
        escrows[_escrowId].paidToProviderAmount = providerPayoutCan;

        require(escrowToken.transfer(escrows[_escrowId].provider, escrows[_escrowId].paidToProviderAmount), "Escrow must hold enough CAN for payout");

        emit OnCompleteEscrow(escrowDapp, _escrowId);

        return true;
    }
    
    /**
     * @dev Get the total amount of CAN to pay out for the job, based on the DAI value
     * @param _escrowId Id of the escrow to complete
     * @return uint256 amount of CAN
     */
    function getTotalPayoutCAN(uint _escrowId) 
    internal
    view 
    returns (uint256) {
        uint256 totalPayoutCAN = priceOracle.getDaiToToken(escrows[_escrowId].totalValueDai);
        require(totalPayoutCAN > 0, "Oracle must return a non zero payout");
        if(totalPayoutCAN >= escrows[_escrowId].amount.mul(2)){ // max payout in CAN is 2x initial pay in
            return escrows[_escrowId].amount.mul(2);
        }
        return totalPayoutCAN;
    }

    /**
     * @dev The provider wishes to cancel the job before he begins working on it
     * Pay out 100% of the DAI value in CAN back to the client
     * @param _escrowId Id of the escrow to complete
     * @return bool success
     */
    function cancelEscrowByProvider(uint256 _escrowId) 
    internal 
    returns (bool) {
        require(escrows[_escrowId].status == EscrowStatus.New, "Escrow status must be 'new'");
        require(escrows[_escrowId].provider == msg.sender, "Transaction must be sent by provider");

        escrows[_escrowId].payoutAmount = getTotalPayoutCAN(_escrowId);

        escrows[_escrowId].paidToClientAmount = escrows[_escrowId].payoutAmount;
        escrows[_escrowId].status = EscrowStatus.Cancelled;
        escrows[_escrowId].closedAt = block.number;

        require(escrowToken.transfer(escrows[_escrowId].client, escrows[_escrowId].paidToClientAmount), "Client must receive payment");

        emit OnCancelEscrowByProvider(escrowDapp, _escrowId);

        return true;
    }    

    /**
     * @dev The escrow finishes early, so we split the money between the parties, and the rest goes back
     * to the client. We calculate payout from the DAI value
     * @param _escrowId Id of the escrow to finalise
     * @param _payToClientPercentage Percent of remaining funds to give to client
     * @param _payToProviderPercentage Percent of remaining funds to give to client
     * @param _arbiter Address of the arbiter
     * @param _payToArbiterPercentage Percentage of remaining funds to give to arbiter
     * @return bool success
     */
    function cancelEscrow(uint256 _escrowId, uint8 _payToClientPercentage, uint8 _payToProviderPercentage, address _arbiter, uint8 _payToArbiterPercentage) 
    internal 
    returns (bool) {
        require(escrows[_escrowId].status == EscrowStatus.New, "Escrow status must be 'new'");
        require(_payToClientPercentage >= 0 && _payToProviderPercentage >= 0 && _payToArbiterPercentage >= 0
            && _payToClientPercentage <= 100 && _payToProviderPercentage <= 100 && _payToArbiterPercentage <= 100, "Payments to client, provider and arbiter must be gte 0");
        require((_payToClientPercentage + _payToProviderPercentage + _payToArbiterPercentage) == 100, "Total payout must equal 100 percent");

        escrows[_escrowId].status = EscrowStatus.Cancelled;        
        escrows[_escrowId].closedAt = block.number;

        escrows[_escrowId].payoutAmount = getTotalPayoutCAN(_escrowId);

        uint256 payToDappAmount = escrows[_escrowId].payoutAmount.mul(DAPP_PAYMENT_PERCENTAGE).div(100);
        if (payToDappAmount > 0){
            escrows[_escrowId].paidToDappAmount = payToDappAmount;
            require(escrowToken.transfer(escrowDapp, payToDappAmount), "Dapp must receive payment");
        }

        uint payoutToSplit = escrows[_escrowId].payoutAmount.sub(payToDappAmount);

        if (_payToArbiterPercentage > 0) {
            require(_arbiter != address(0), "Arbiter address must be valid");
            escrows[_escrowId].paidToArbiterAmount = payoutToSplit.mul(_payToArbiterPercentage).div(100);
            require(escrowToken.transfer(_arbiter, escrows[_escrowId].paidToArbiterAmount), "Arbiter must receive payment");
        }                

        if (_payToProviderPercentage > 0) {
            escrows[_escrowId].paidToProviderAmount = payoutToSplit.mul(_payToProviderPercentage).div(100);
            require(escrowToken.transfer(escrows[_escrowId].provider, escrows[_escrowId].paidToProviderAmount), "Provider must receive payment");
        }        
             
        if (_payToClientPercentage > 0) {
            escrows[_escrowId].paidToClientAmount = payoutToSplit.mul(_payToClientPercentage).div(100); 
            require(escrowToken.transfer(escrows[_escrowId].client, escrows[_escrowId].paidToClientAmount), "Client must receive payment");
        }       

        emit OnCancelEscrow(escrowDapp, _escrowId, escrows[_escrowId].paidToProviderAmount, _arbiter, escrows[_escrowId].paidToArbiterAmount); 

        return true;
    }

    /** 
      * @dev Internal update the address of price oracle
      * @param _oracle Address
      */
    function updateInternalOracleAddress(address _oracle) 
    internal {
        priceOracle = ERC20BancorPriceOracle(_oracle);
    }

    function getEscrow(uint256 _escrowId) 
    public 
    view
    returns (
      address client, 
      address provider, 
      uint256 amount, 
      uint256 totalValueDai, 
      uint8 status, 
      uint256 createdAt, 
      uint256 closedAt) 
      {      
        require(_escrowId > 0 && escrows[_escrowId].createdAt > 0, "Must be a valid escrow Id");
        return (
            escrows[_escrowId].client, 
            escrows[_escrowId].provider, 
            escrows[_escrowId].amount, 
            escrows[_escrowId].totalValueDai, 
            uint8(escrows[_escrowId].status),
            escrows[_escrowId].createdAt, 
            escrows[_escrowId].closedAt
            );       
    }

    function getEscrowPayments(uint256 _escrowId) 
    public 
    view
    returns (
      uint256 amount, 
      uint256 totalValueDai, 
      uint256 payoutAmount,
      uint256 paidToDappAmount,
      uint256 paidToProviderAmount,
      uint256 paidToClientAmount,      
      uint256 paidToArbiterAmount)
      {      
        require(_escrowId > 0 && escrows[_escrowId].createdAt > 0, "Must be a valid escrow Id");
        return (
            escrows[_escrowId].amount, 
            escrows[_escrowId].totalValueDai, 
            escrows[_escrowId].payoutAmount, 
            escrows[_escrowId].paidToDappAmount,
            escrows[_escrowId].paidToProviderAmount,
            escrows[_escrowId].paidToClientAmount,        
            escrows[_escrowId].paidToArbiterAmount
            );       
    }    
}