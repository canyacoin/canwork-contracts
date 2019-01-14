pragma solidity 0.4.24;

import "./Escrow.sol";

contract CanWorkAdmin {
    function addSig(address signer, bytes32 id) external returns (uint8);
    function resetSignature(bytes32 id) external returns (bool);  
    function getSignersCount(bytes32 id) external view returns (uint8);
    function getSigner(bytes32 id, uint index) external view returns (address,bool);
    function hasRole(address addr, string roleName) external view returns (bool);
}

contract CanWorkJob is Escrow {
    
    using SafeMath for uint256;
    
    CanWorkAdmin canworkAdmin;    
    string public constant ROLE_ADMIN = "admin";
    string public constant ROLE_OWNER = "owner";

    enum JobStatus {
        New,
        Completed,
        Cancelled
    }

    struct Job {
        bytes32 id;
        address client;
        address provider;
        uint256 escrowId;
        JobStatus status;
        uint256 amount;
    }

    mapping(bytes32 => Job) internal jobs;
    address dApp;

    event OnCreateJob(address indexed dapp, bytes32 indexed jobId, address client, address indexed provider, uint256 totalCosts);
    event OnCompleteJob(address indexed dapp, bytes32 indexed jobId);
    event OnCancelJobByProvider(address indexed dapp, bytes32 indexed jobId);
    event OnCancelJobByAdmin(address indexed dapp, bytes32 indexed jobId, uint8 payToProviderPercentage, address indexed arbiter, uint8 payToArbiterPercentage);

    function initialize(ERC20 _token, CanWorkAdmin _canworkAdmin, address _dApp, address _priceOracle)
    public 
    isInitializer("CanWorkJob", "0.1.3") {
        require(_token != address(0) && _canworkAdmin != address(0) && _dApp != address(0) && _priceOracle != address(0));
        Escrow.initialize(_token, _dApp, _priceOracle);
        canworkAdmin = CanWorkAdmin(_canworkAdmin);
        dApp = _dApp;
    }

    /** 
      * @dev Update the address of price oracle
      * @param _oracle Address
      */
    function updatePriceOracleAddress(address _oracle) 
    public {
        require(_oracle != address(0) && _oracle != address(priceOracle), "Must be valid, new address");
        require(canworkAdmin.hasRole(msg.sender, ROLE_OWNER), "Only owner can update");
        updateInternalOracleAddress(_oracle);
    }

    function createJob(bytes32 _jobId, address _client, address _provider, uint256 _totalCosts) 
    public 
    returns (bool) {
        require(_jobId[0] != 0);
        require(jobs[_jobId].id[0] == 0);

        jobs[_jobId].id = _jobId;
        jobs[_jobId].client = _client;
        jobs[_jobId].provider = _provider;
        jobs[_jobId].status = JobStatus.New;
        jobs[_jobId].amount = _totalCosts;
        jobs[_jobId].escrowId = createEscrow(_client, _provider, _totalCosts);

        emit OnCreateJob(dApp, _jobId, _client, _provider, _totalCosts);

        return true;
    }

    function completeJob(bytes32 _jobId) 
    public 
    returns (bool) {  
        require(_jobId[0] != 0);
        require(jobs[_jobId].status == JobStatus.New);
        require(jobs[_jobId].client == msg.sender);   
        
        require(completeEscrow(jobs[_jobId].escrowId));
        
        jobs[_jobId].status = JobStatus.Completed;

        emit OnCompleteJob(dApp, _jobId);

        return true;
    }

    function cancelJobByProvider(bytes32 _jobId) 
    public 
    returns (bool) {
        require(_jobId[0] != 0);  
        require(jobs[_jobId].status == JobStatus.New);
        require(jobs[_jobId].provider == msg.sender);
        
        require(cancelEscrowByProvider(jobs[_jobId].escrowId));
        
        jobs[_jobId].status = JobStatus.Cancelled;

        emit OnCancelJobByProvider(dApp, _jobId);

        return true;
    }

    function cancelJobByAdmin(bytes32 _jobId, uint8 _payToClientPercentage, uint8 _payToProviderPercentage, address _arbiter, uint8 _payToArbiterPercentage)
    public 
    returns (bool) {
        require(_jobId[0] != 0, "Must be valid jobId");  
        require(jobs[_jobId].status == JobStatus.New);
        require(canworkAdmin.hasRole(msg.sender, ROLE_ADMIN));
        require(_payToArbiterPercentage <= 5, "Arbiter cannot receive more than 5% of funds");
        
        require(cancelEscrow(jobs[_jobId].escrowId, _payToClientPercentage, _payToProviderPercentage, _arbiter, _payToArbiterPercentage));

        jobs[_jobId].status = JobStatus.Cancelled;

        emit OnCancelJobByAdmin(dApp, _jobId, _payToProviderPercentage, _arbiter, _payToArbiterPercentage);

        return true;
    }

    function getJob(bytes32 _jobId) 
    public 
    view 
    returns (
      address client, 
      address provider,
      uint256 amount,
      uint256 valueInDai, 
      uint8 status, 
      uint256 createdAt, 
      uint256 closedAt
      ) {
        require(_jobId[0] != 0, "Must be valid jobId"); 
        require(jobs[_jobId].id[0] != 0, "Job must exist");

        return getEscrow(jobs[_jobId].escrowId);
    }

    function getJobPayments(bytes32 _jobId) 
    public 
    view 
    returns (
      uint256 amount,  
      uint256 valueInDai,
      uint256 payoutAmount,
      uint256 paidToDappAmount,
      uint256 paidToProviderAmount,
      uint256 paidToClientAmount,
      uint256 paidToArbiterAmount
      ) {
        require(_jobId[0] != 0, "Must be valid jobId"); 
        require(jobs[_jobId].id[0] != 0, "Job must exist");

        return getEscrowPayments(jobs[_jobId].escrowId);
    } 
}