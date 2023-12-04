// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

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
    }

    using ABDKMath64x64 for uint256;  

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

  function getMinerData() public {
      uint256 total = IBattledog(battledogs).balanceOf(msg.sender);
      IBattledog.Player[] memory players = IBattledog(battledogs).getPlayerOwners(msg.sender);
      
      for (uint256 i = 0; i < total; i++) {
          uint256 tokenId = players[i].id;  
          bool state =  IBattledog(battledogs).blacklisted(tokenId);
        // Require Miner is not on blacklist
        if (!state) {
        address owner = IBattledog(battledogs).ownerOf(tokenId);
            // compare the _tokenId 
            if (owner == msg.sender) {
                // Update the ActiveMiner array with the player's data
                ActiveMiners[tokenId] = players[i];
                }            
                // Increment the activeMinersLength when necessary
                if (!minerstate[tokenId]) {
                    activeMinersLength++;
                    minerstate[tokenId] = true;
                }            

        }
      }
  }

    function getActiveMiner(uint256 index) public view returns (IBattledog.Player memory) {
        require(index < activeMinersLength, "Index out of range.");
        return ActiveMiners[index];
    }

    function mineGAME(uint256[] calldata _nfts) public nonReentrant {
    // Require Contract isn't paused
    require(!paused, "Paused Contract");

      uint256 total = IBattledog(battledogs).balanceOf(msg.sender);
      IBattledog.Player[] memory players = IBattledog(battledogs).getPlayerOwners(msg.sender);
      
      for (uint256 i = 0; i < total; i++) {
          uint256 tokenId = players[i].id;  
          bool state =  IBattledog(battledogs).blacklisted(tokenId);
        // Require Miner is not on blacklist
        if (!state) {
        address owner = IBattledog(battledogs).ownerOf(tokenId);
            // compare the _tokenId 
            if (owner == msg.sender) {
                // Update the ActiveMiner array with the player's data
                ActiveMiners[tokenId] = players[i];
                }            
                // Increment the activeMinersLength when necessary
                if (!minerstate[tokenId]) {
                    activeMinersLength++;
                    minerstate[tokenId] = true;
                }            

        }
      }

        for (uint256 a = 0; a < _nfts.length; a++) {
            uint256 tokenId = _nfts[a]; // Current NFT id       
            // Require Each Miner hasn't claimed within timelock   
            uint256 unlock = MinerClaims[tokenId] + timeLock;  
            uint256 currentTime = block.timestamp;
            if (currentTime > unlock) {
                // Check if the miner is activated
                if (ActiveMiners[tokenId].activate > 0) {

                    // Calculate Rewards
                    uint256 activatefactor = (ActiveMiners[tokenId].activate - 1) * activatebonus;
                    uint256 activate = ((ActiveMiners[tokenId].activate - 1)) * multiplier;
                    uint256 level = ((ActiveMiners[tokenId].level - Collectors[tokenId].level) * levelbonus) + activatefactor;
                    uint256 fights = ((ActiveMiners[tokenId].fights - Collectors[tokenId].fights) * fightsbonus) + activatefactor;
                    uint256 wins = ((ActiveMiners[tokenId].wins - Collectors[tokenId].wins) * winsbonus) + activatefactor;
                    uint256 history = ((ActiveMiners[tokenId].history - Collectors[tokenId].history) * historybonus) + activatefactor;
                    uint256 rewards = (activate + level + fights + wins + history) * divisor;

                    // Check the contract for adequate withdrawal balance
                    require(GAMEToken.balanceOf(address(this)) > rewards, "Not Enough Reserves");      
                    // Transfer the rewards amount to the miner
                    require(GAMEToken.transfer(msg.sender, rewards), "Failed Transfer");
                    
                    // Register claim
                        // Read the miner data from the ActiveMiners mapping
                        IBattledog.Player memory activeMiner = ActiveMiners[tokenId];

                        // Transfer the miner data to the Collectors mapping
                        Collectors[tokenId] = Miner(
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

                    // Register claim timestamp
                    MinerClaims[tokenId] = currentTime; // Record the miner's claim timestamp
                    // TotalClaimedRewards
                    totalClaimedRewards += rewards;       
                    // Emit event
                    emit RewardClaimedByMiner(msg.sender, rewards);
                } 
            } else {
                require(currentTime > unlock, 'Timelocked');
            }

            }
    }

    function setTimeLock(uint256 _seconds) external onlyOwner {
        timeLock = _seconds;
    }

    function setMultiplier (uint256 _multiples) external onlyOwner() {
        multiplier = _multiples;
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
