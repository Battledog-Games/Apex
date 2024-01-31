// SPDX-License-Identifier: No license

// @title NFT Game by OxSorcerers for Battledog Games (Apexchain)
// https://twitter.com/0xSorcerers | https://github.com/Dark-Viper | https://t.me/Oxsorcerer | https://t.me/battousainakamoto | https://t.me/darcViper

pragma solidity ^0.8.17;

contract Harvester is Ownable, ReentrancyGuard {
    IERC20 public GAMEToken;
    IERC20 public payToken;
    uint256 public totalRewards = 1;
    uint256 public allRewardsOwed;
    uint256 public eralength = 300;
    uint256 public totalClaimedRewards;
    uint256 public immutable startTime;
    uint256 public rewardPerStamp;
    uint256 public numberOfParticipants = 0;
    uint256 public Duration = 300;
    uint256 public timeLock = 2;
    uint256 public TotalGAMESent = 1;
    uint256 public tax = 0;
    uint256 public TaxTotal = 0;
    uint256 public replenishTax = 0;
    uint256 public currentReplenish;
    uint256 public totalReplenish;
    uint256 public ERA = 0;
    uint256 public eraClock;
    uint256 public liveDays;
    uint256 private divisor = 100 ether;
    address private guard;  
    address public battledogs;
    bool public paused = false;   
    bool public replenisher = false; 

    mapping(address => uint256) public balances;
    mapping(address => Claim) public claimRewards;
    mapping(address => uint256) public entryMap;
    mapping(address => uint256) public UserClaims;
    mapping(address => bool) public blacklist;
    mapping(address => uint256) public Claimants;
    mapping(uint256 => uint256) public eraRewards;

    address[] public participants;

    struct Claim {
        uint256 eraAtBlock;
        uint256 GAMESent;
        uint256 rewardsOwed;
    }
    
    event RewardsUpdated(uint256 totalRewards);
    event RewardAddedByDev(uint256 amount);
    event RewardClaimedByUser(address indexed user, uint256 amount);
    event AddGAME(address indexed user, uint256 amount);
    event WithdrawGAME(address indexed user, uint256 amount);
    
    constructor(
        address _GAMEToken,
        address _payToken,
        address _battledogs,
        address _newGuard
    ) {
        GAMEToken = IERC20(_GAMEToken);
        payToken = IERC20(_payToken);
        battledogs = _battledogs;
        guard = _newGuard;
        startTime = block.timestamp;
        eraClock = startTime;
    }

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    modifier onlyAfterTimelock() {             
        require(entryMap[msg.sender] + timeLock < block.timestamp, "Timelocked.");
        _;
    }

    modifier onlyClaimant() {             
        require(UserClaims[msg.sender] + timeLock < block.timestamp, "Timelocked.");
        _;
    }

    function setEra() internal {
        uint256 timeElapsed = block.timestamp - startTime; // time elapsed in secs        
        uint256 totalDaysElapsed = timeElapsed / eralength; //  total Days since deploy

        uint256 daysElapsed = totalDaysElapsed - liveDays; // ensure uniformity by deducting days already recorded

        if (daysElapsed > 0) {
            liveDays += daysElapsed;
            for (uint256 i = 0; i < daysElapsed; i++) {
            // set rewards for each new ERA
                eraRewards[ERA] = rewardPerStamp; // cumulative rate over a net 7 day period
            //increment Era
            ERA++;
            }
        // Update the eraClock of current timestamp
        eraClock = block.timestamp;
        }   
    }

    function addGAME(uint256 _amount) public nonReentrant {
        require(!paused, "Contract is paused.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(!blacklist[msg.sender], "Address is blacklisted.");
        require(GAMEToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed.");
        setEra();
        Claim storage claimData = claimRewards[msg.sender];
        uint256 toll = (_amount * tax)/100;
        uint256 amount = _amount - toll;
        TaxTotal += toll;
        uint256 currentBalance = balances[msg.sender];
        uint256 newBalance = currentBalance + amount;
        balances[msg.sender] = newBalance;
        entryMap[msg.sender] = block.timestamp; // record the user's entry timestamp

        if (currentBalance == 0) {
            participants.push(msg.sender);
            numberOfParticipants += 1;
         // set the era period for the user
            claimData.eraAtBlock = ERA;
        }

        getClaim();
    
        claimData.GAMESent += amount;
        TotalGAMESent += amount;
        setRewards();
        emit AddGAME(msg.sender, _amount);
    }

    /**
    * @dev Allows the user to withdraw their GAME tokens
    */
    function withdrawGAME() public nonReentrant onlyAfterTimelock {
        require(!paused, "Contract already paused.");
        require(balances[msg.sender] > 0, "No GAME tokens to withdraw."); 
        Claim storage claimData = claimRewards[msg.sender];       
        uint256 GAMEAmount = balances[msg.sender];
        require(GAMEToken.transfer(msg.sender, GAMEAmount), "Failed Transfer");    

        balances[msg.sender] = 0;
        claimData.GAMESent = 0;
        TotalGAMESent -= GAMEAmount;

       setRewards();
       setEra();

        if (numberOfParticipants > 0) {
            numberOfParticipants -= 1;
            entryMap[msg.sender] = 0; // reset the user's entry timestamp
        }
        
        emit WithdrawGAME(msg.sender, GAMEAmount);
    }

    /**
    * @dev Adds new rewards to the contract
    * @param _amount The amount of rewards to add
    */
    function addRewards(uint256 _amount) external onlyOwner {
        payToken.transferFrom(msg.sender, address(this), _amount);
        setRewards();
        emit RewardAddedByDev(_amount);
    }

    function setRewards() internal {
        uint256 contract_balance = payToken.balanceOf(address(this));
        // ensure rewards are equally disbursed
        if (contract_balance > allRewardsOwed) {            
            totalRewards = contract_balance - allRewardsOwed;
        } else  {
            totalRewards = 0;
        }
        updateRewardPerStamp();        
        eraRewards[ERA] = rewardPerStamp;        
        emit RewardsUpdated(totalRewards);
    }

    function resetRewards() external onlyOwner {
        setRewards();
    }

    function getClaim() internal {
            Claim storage claimData = claimRewards[msg.sender];// call the details for participant
            uint256 startPeriod = claimData.eraAtBlock;
            uint256 endPeriod = ERA;
            
            if (blacklist[msg.sender]) {
                claimData.rewardsOwed = 0;
            } else {
                //Find a way to calculate rewards for each ERA 
                uint256 rewardsAccrued;
                for (uint256 i = startPeriod; i < endPeriod; i++) {
                rewardsAccrued = (eraRewards[i] * claimData.GAMESent);
                claimData.rewardsOwed += rewardsAccrued;
                }             
            }
            claimData.eraAtBlock = ERA;
            uint256 rewardsDue = claimData.rewardsOwed / divisor;
            allRewardsOwed += rewardsDue;
    }

    function updateRewardPerStamp() internal {
        rewardPerStamp = (totalRewards * divisor) / (TotalGAMESent * Duration);
    }

    function claim() public nonReentrant onlyClaimant {  
        require(!paused, "Contract already paused.");         
        require(!blacklist[msg.sender], "Address is blacklisted.");
        Claim storage claimData = claimRewards[msg.sender];
        if (claimData.eraAtBlock == ERA) {
        require(claimRewards[msg.sender].rewardsOwed > 0, "No rewards.");
        } else {            
        getClaim(); 
        }

        uint256 userRewards = claimData.rewardsOwed;

        uint256 replenished = (userRewards / 100) * replenishTax; 
        uint256 estimatedRewards = userRewards - replenished;

        uint256 rewards =  estimatedRewards / divisor;
        uint256 replenish = replenished / divisor;
        
        require(payToken.transfer(msg.sender, rewards), "Transfer failed."); 
        require(payToken.transfer(battledogs, replenish), "Transfer failed."); 

        //reset rewardsOwed      
        claimData.rewardsOwed = 0;

        //deduct rewards owed to avoid double-spend
        uint256 spentRewards = rewards + replenish;
        allRewardsOwed -= spentRewards; 

        // Update the total rewards claimed by the user
        Claimants[msg.sender] += rewards;
        totalClaimedRewards += rewards;
        currentReplenish += replenish;
        totalReplenish += replenish;
        setRewards();
        setEra();
        UserClaims[msg.sender] = block.timestamp; // record the user's claim timestamp       
        emit RewardClaimedByUser(msg.sender, rewards);
    }

    function withdraw(uint256 _binary, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero.");
        if (_binary > 1) {
            require(payToken.balanceOf(address(this)) >= amount, "Not Enough Reserves.");
            require(payToken.transfer(msg.sender, amount), "Transfer failed.");
        } else {
            require(amount <= TaxTotal, "Max Exceeded.");
            require(GAMEToken.balanceOf(address(this)) >= TaxTotal, "Not enough Reserves.");
            require(GAMEToken.transfer(msg.sender, amount), "Transfer failed.");
            TaxTotal -= amount;
        }
    }

    function setDuration(uint256 _seconds) external onlyOwner {        
        getClaim();
        Duration = _seconds;
        updateRewardPerStamp();
    }

    function setTimeLock(uint256 _seconds) external onlyOwner {
        timeLock = _seconds;
    }

    function setEraLength(uint256 _seconds) external onlyOwner {
        eralength = _seconds;
    }

    function setTaxes (uint256 _stakeTax, uint256 _replenishTax ) external onlyOwner {
        tax = _stakeTax;
        replenishTax = _replenishTax;
    }

    function setGAMEToken(address _GAMEToken) external onlyOwner {
        GAMEToken = IERC20(_GAMEToken);
    }

    function setPayToken(address _payToken) external onlyOwner {
        payToken = IERC20(_payToken);
    }

    function setBattledogs (address _battledogs) external onlyOwner {
        battledogs = _battledogs;
    }

    function addToBlacklist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            blacklist[_addresses[i]] = true;
        }
    }

    function removeFromBlacklist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            blacklist[_addresses[i]] = false;
        }
    }

    event Pause();
    function pause() public onlyGuard {
        require(!paused, "Contract already paused.");
        paused = true;
        emit Pause();
    }

    event Unpause();
    function unpause() public onlyGuard {
        require(paused, "Contract not paused.");
        paused = false;
        emit Unpause();
    }

    function setGuard (address _newGuard) external onlyGuard {
        guard = _newGuard;
    }

    event ReplenishOn();
    function replenishOn(uint256 _replenishTax) external onlyOwner{
        require(!replenisher, "Replish already turned off.");
        replenisher = true;
        replenishTax = _replenishTax;
        emit ReplenishOn();
    }

    event ReplenishOff();
    function replenishOff() external onlyOwner {
        require(replenisher, "Replenish is in progress.");
        replenishTax = 0;
        currentReplenish = 0;
        replenisher = false;
        emit ReplenishOff();
    }
}              
