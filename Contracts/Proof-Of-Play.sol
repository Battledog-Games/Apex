// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

interface IBattledog {
    struct Player {
        string name;
        uint256 id;
        uint256 level;
        uint256 attack;
        uint256 defence;
        uint256 fights;
        uint256 wins;
        uint256 payout;
        uint256 activate;
        uint256 history;
    }

    function balanceOf(address _caller) external view returns (uint256);
    function getPlayerOwners(address _user) external returns (Player[] memory);
    function ownerOf(uint256 _index) external view returns (address);
    function blacklisted(uint256 _index) external view returns (bool);
}

/**
 * @title Proof of Play Miner contract
 */
contract ProofOfPlay is Ownable, ReentrancyGuard {
    IERC20 public GAMEToken;
    uint256 public totalClaimedRewards;
    uint256 public multiplier = 10;
    uint256 public timeLock = 604800;
    uint256 private divisor = 1 ether;
    address private guard; 
    address public battledogs;
    bool public paused = false; 
    uint256 public activatebonus = 5;
    uint256 public levelbonus = 4;
    uint256 public winsbonus = 3;
    uint256 public fightsbonus = 2;
    uint256 public historybonus = 1;
    uint256 private startTime;
        

    // Declare the ActiveMiners & Blacklist arrays
    uint256 public activeMinersLength;

    mapping(uint256 => IBattledog.Player) public ActiveMiners;
    mapping(uint256 => Miner) public Collectors;
    mapping(uint256 => uint256) public MinerClaims;
    mapping(uint256 => bool) private minerstate;

    struct Miner {
        string name;
        uint256 id;
        uint256 level;
        uint256 attack;
        uint256 defence;
        uint256 fights;
        uint256 wins;
        uint256 payout;
        uint256 activate;
        uint256 history;
    }

    event RewardClaimedByMiner (address indexed user, uint256 amount);
    
    constructor(
        address _GAMEToken,
        address _battledogs,
        address _newGuard
    ) {
        GAMEToken = IERC20(_GAMEToken);
        battledogs = _battledogs;
        guard = _newGuard;
        startTime = block.timestamp;
    }

    using ABDKMath64x64 for uint256;  

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    function getMinerData() public nonReentrant {
    uint256 total = IBattledog(battledogs).balanceOf(msg.sender);
    IBattledog.Player[] memory players = IBattledog(battledogs).getPlayerOwners(msg.sender);
    
      for (uint256 i = 0; i < total; i++) {
        uint256 tokenId = players[i].id;

        // Create a new instance of the Miner struct with the player's data
        ActiveMiners[tokenId] = players[i];
        
        // Increment the activeMinersLength
        if (!minerstate[tokenId]) {
          activeMinersLength++;
        }

        minerstate[tokenId] = true;
      }
    }

    function getActiveMiner(uint256 index) public view returns (IBattledog.Player memory) {
        require(index < activeMinersLength, "Index out of range.");
        return ActiveMiners[index];
    }

    function getOwnerData(uint256 _tokenId) internal view returns (bool) {        
    // Get the token id owned by the msg.sender
      address owner = IBattledog(battledogs).ownerOf(_tokenId);
        // compare the _tokenId 
        if (owner == msg.sender) {
                return true;
              }        
          return false;
    }

    function mineGAME(uint256[] calldata _nfts) public nonReentrant {
    // Require Contract isn't paused
    require(!paused, "Paused Contract");
    // Populate the ActiveMiners array
    uint256 total = IBattledog(battledogs).balanceOf(msg.sender);
    IBattledog.Player[] memory players = IBattledog(battledogs).getPlayerOwners(msg.sender);
    
    for (uint256 i = 0; i < total; i++) {
        uint256 tokenId = players[i].id;
        // Create a new instance of the Miner struct with the player's data
        ActiveMiners[tokenId] = players[i];
        
        // Increment the activeMinersLength
        if (!minerstate[tokenId]) {
          activeMinersLength++;
          minerstate[tokenId] = true;
        }

    }

        for (uint256 a = 0; a < _nfts.length; a++) {
            uint256 tokenId = _nfts[a]; // // Current NFT id
            // Require Token Ownership    
            require(getOwnerData(tokenId), "Not Owner");        
            // Require Miner hasn't claimed within timelock  
              uint256 unlock = MinerClaims[tokenId] + timeLock;  
              uint256 currentTime = block.timestamp;
            require(unlock < currentTime, "Timelocked");
            // Require Miner is not on blacklist
            require(!IBattledog(battledogs).blacklisted(tokenId), "NFT Blacklisted");

            // Check if the miner is activated
            if (ActiveMiners[tokenId].activate > 0) {
            uint256 freq; uint256 activatefactor; uint256 activate; uint256 level; 
            uint256 fights; uint256 wins; uint256 history; uint256 rewards;

              // Calculate Rewards
              if (MinerClaims[tokenId] > 0) {                
              freq = (currentTime - MinerClaims[tokenId]) / timeLock;
              } else if (((currentTime - startTime) / timeLock) < 0) {
                freq = 1;
              } else {
                freq = ((currentTime - startTime) / timeLock);
              }

              activatefactor = (ActiveMiners[tokenId].activate - 1) * activatebonus;
              activate = ((ActiveMiners[tokenId].activate - 1)) * multiplier * freq;
              level = ((ActiveMiners[tokenId].level - Collectors[tokenId].level) * levelbonus) + activatefactor;
              
              if (ActiveMiners[tokenId].fights > Collectors[tokenId].fights) {  
              fights = ((ActiveMiners[tokenId].fights - Collectors[tokenId].fights) * fightsbonus) + activatefactor;
              }

              if (ActiveMiners[tokenId].wins > Collectors[tokenId].wins) {
              wins = ((ActiveMiners[tokenId].wins - Collectors[tokenId].wins) * winsbonus) + activatefactor;
              }

              history = ((ActiveMiners[tokenId].history - Collectors[tokenId].history) * historybonus) + activatefactor;
              rewards = (activate + level + fights + wins + history) * divisor;

                // Check the contract for adequate withdrawal balance
                require(GAMEToken.balanceOf(address(this)) > rewards, "Not Enough Reserves");      
                // Transfer the rewards amount to the miner
                require(GAMEToken.transfer(msg.sender, rewards), "Failed Transfer");
                // Register claim
                getCollectors(tokenId);
                // Register claim timestamp
                MinerClaims[tokenId] = currentTime; // Record the miner's claim timestamp
                // TotalClaimedRewards
                totalClaimedRewards += rewards;       
                // Emit event
                emit RewardClaimedByMiner(msg.sender, rewards);
            } else {
                require(ActiveMiners[tokenId].activate > 0, "ActivateUp Required");
            }
        }
    }

    function getCollectors(uint256 _tokenId) internal {
        // Read the miner data from the ActiveMiners mapping
        IBattledog.Player memory activeMiner = ActiveMiners[_tokenId];

        // Transfer the miner data to the Collectors mapping
        Collectors[_tokenId] = Miner(
            activeMiner.name,
            activeMiner.id,
            activeMiner.level,
            activeMiner.attack,
            activeMiner.defence,
            activeMiner.fights,
            activeMiner.wins,
            activeMiner.payout,
            activeMiner.activate,
            activeMiner.history
        );
    }
    
    function setCollectors (string memory _name, uint256 _id, uint256 _level, 
    uint256 _attack, uint256 _defence, uint256 _fights, uint256 _wins, 
    uint256 _payout, uint256 _activate, uint256 _history, uint256 _time) external onlyOwner nonReentrant {
       Collectors[_id] = Miner(
        _name,
        _id,
        _level,
        _attack,
        _defence,
        _fights,
        _wins,
        _payout,
        _activate,
        _history
        );  
        
      MinerClaims[_id] = _time; // Record the miner's claim timestamp
    }

    function setTimeLock(uint256 _seconds) external onlyOwner {
        timeLock = _seconds;
    }

    function setMultiplier (uint256 _multiples) external onlyOwner() {
        multiplier = _multiples;
    }

    function setTime(uint256 _time) external onlyOwner {
      startTime = _time;
    }

    function setBonuses (uint256 _activate, uint256 _level, uint256 _wins, uint256 _fights, uint256 _history) external onlyOwner() {
        activatebonus = _activate;
        levelbonus = _level;
        winsbonus = _wins;
        fightsbonus = _fights;
        historybonus = _history;
    }

    function setGuard (address _newGuard) external onlyGuard {
        guard = _newGuard;
    }

    function setBattledog (address _battledog) external onlyGuard {
        battledogs = _battledog;
    }

    function setGametoken (address _gametoken) external onlyGuard {
        GAMEToken = IERC20(_gametoken);
    }

    function withdrawERC20(IERC20 _paytoken, uint256 _amount) external payable onlyOwner {
        IERC20 paytoken = _paytoken;
        paytoken.transfer(msg.sender, _amount);
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
}                      
