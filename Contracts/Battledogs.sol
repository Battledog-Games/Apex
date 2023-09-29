// SPDX-License-Identifier: No license

// @title NFT Game by OxSorcerers for Battledog Games (Apexchain)
// https://twitter.com/0xSorcerers | https://github.com/Dark-Viper | https://t.me/Oxsorcerer | https://t.me/battousainakamoto | https://t.me/darcViper

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract battledog is ERC721Enumerable, Ownable, ReentrancyGuard {        
        constructor(string memory _name, string memory _symbol, address GAMEAddress, address _newGuard) 
            ERC721(_name, _symbol)
        {
            GAME = GAMEAddress;
            guard = _newGuard;
        }
    using Math for uint256;
    using ABDKMath64x64 for uint256;    
    using SafeERC20 for IERC20;  

    uint256 COUNTER = 0;
    uint256 public mintFee = 2059.117256432168 ether;
    uint256 public _pid = 0;
    uint256 public _pay = 1;
    uint256 public requiredAmount = 2000000 * 10**6;
    uint256 public activatingAmount = 20000000 * 10**6;
    uint256 private divisor = 1 * 10**6;
    uint256 public TotalContractBurns = 0;
    uint256 public TotalGAMEBurns = 0;    
    uint256 BattlesTotal = 0; 
    using Strings for uint256;
    string public baseURI;
    address private guard; 
    address public GAME;
    string public Author = "0xSorcerer";
    bool public paused = false; 
    address payable public developmentAddress;
    address payable public bobbAddress;       
    address public saveAddress;
    uint256 public deadtax;
    uint256 public bobbtax;
    uint256 public devtax;

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    modifier onlyBurner() {
        require(msg.sender == GAME, "Not authorized.");
        _;
    }

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

     struct TokenInfo {
        IERC20 paytoken;
    }

    struct Assaulter {
        uint256 attackerId;
        uint256 defenderId;        
        uint256 stolenPoints;
        uint256 timestamp;
    }

    struct Debilitator {
        uint256 attackerId;
        uint256 defenderId;        
        uint256 stolenPoints;
        uint256 timestamp;        
    }

    struct BlackList {
        bool blacklist;       
    }

    //Arrays
    TokenInfo[] public AllowedCrypto;

    // Mapping
    mapping (uint256 => Player) public players;
    mapping (uint256 => BlackList) public blacklisted;
    mapping (uint256 => uint256) public functionCalls;
    mapping (uint256 => uint256) private lastReset;
    mapping (uint256 => mapping (uint256 => uint256)) public fightTimestamps;
    mapping (uint256 => Assaulter[]) public assaulters;
    mapping (uint256 => Debilitator[]) public debilitators;

    event TokenMinted(string _name, uint256 indexed tokenId);

    function mint(string memory _name) public payable nonReentrant {
        require(!paused, "Paused Contract");
        require(msg.value == mintFee, "Insufficient fee");
        require(bytes(_name).length > 0, "No Name");
        // Create a new player and map it
        players[COUNTER] = Player({
            name: _name,
            id: COUNTER,
            level: 0,
            attack: 100,
            defence: 100,
            fights: 0,
            wins: 0,
            payout: 0,
            activate: 0,
            history: 0});
        // Mint a new ERC721 token for the player
        uint256 tokenId = COUNTER;
        _mint(msg.sender, tokenId);

        //Create Blacklist and map it
        blacklisted[COUNTER] = BlackList({
            blacklist: false

        });
        
        emit TokenMinted(_name, tokenId);
        COUNTER++;
    }

    function updateName(uint256 _tokenId, string memory _newName) public nonReentrant {
       require(msg.sender == ownerOf(_tokenId), "Not Your NFT.");
       require(bytes(_newName).length > 0, "No Name");
       require(_tokenId >= 0 && _tokenId <= totalSupply(), "Not Found");
        // Update the name in the players mapping
        players[_tokenId].name = string(_newName);
    }

    function setCharge(uint256 _charge) external onlyOwner() {
        charge = _charge;
    }

    function setGAMEAddress (address _GAMEAddress) external onlyOwner {
        require(msg.sender == owner(), "Not Owner.");
        GAME = _GAMEAddress;
    }

    function updateMintFee(uint256 _mintFee) external onlyOwner() {
        mintFee = _mintFee;
    }

    function updatePiD (uint256 pid, uint256 pay) external onlyOwner() {
        _pid = pid;
        _pay = pay;
    }

    function setTax (uint256 _deadtax, uint256 _bobbtax, uint256 _devtax) external onlyOwner() {
        deadtax = _deadtax;
        bobbtax = _bobbtax;
        devtax = _devtax;
    }

    function updateRequiredAmount(uint256 _requiredAmount) external onlyOwner() {
        requiredAmount = _requiredAmount;
    }

    function updateActivatingAmount(uint256 _activatingAmount) external onlyOwner() {
        activatingAmount = _activatingAmount;
    }

    function burn(uint256 _burnAmount, uint256 _num) internal {
        uint256 burnAmount = (_burnAmount * _num)/100 ;

        uint256 tax1 =  (burnAmount * deadtax)/100;
        uint256 tax2 =  (burnAmount * bobbtax)/100;
        uint256 tax3 =  (burnAmount * devtax)/100;

        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;               
        paytoken.transfer(saveAddress, tax1);               
        paytoken.transfer(bobbAddress, tax2); 
        paytoken.transfer(developmentAddress, tax3); 
        TotalContractBurns += burnAmount;       
    }
        
    address public harvesterAddress;

    function burnGAME(uint256 _burnAmount) internal {
        TokenInfo storage tokens = AllowedCrypto[_pay];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        require(paytoken.transferFrom(msg.sender, harvesterAddress, _burnAmount), "Transfer Failed");
        TotalGAMEBurns += _burnAmount;       
    }
    
    function transferTokens(uint256 _cost) internal {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        paytoken.transferFrom(msg.sender,address(this), _cost);
    }

    function activateNFT (uint256 _tokenId) public payable nonReentrant {
        require(!paused, "Paused Contract");
        require(msg.sender == ownerOf(_tokenId), "Not your NFT");
        require(_tokenId > 0 && _tokenId <= totalSupply(), "Not Found");
        require(!blacklisted[_tokenId].blacklist, "Blacklisted"); 
        uint256 cost;
        if(players[_tokenId].activate > 0) {
            require(players[_tokenId].wins >= 5, "Insufficient wins!");   
            // Calculate the payout cost  
            uint256 payreward = ((requiredAmount - (requiredAmount/10))/divisor) * 5 * 5; 
            players[_tokenId].payout -= payreward;
            players[_tokenId].wins -= 5;
            cost = payreward * divisor;  
            //Initiate a 100% burn from the contract       
            burn(cost, 100);   
        } else {               
            cost = activatingAmount;   
            //Transfer Required Tokens to Activate NFT        
            transferTokens(cost); 
            //Initiate a 10% burn from the contract       
            burn(cost, 10); 
        }     
        // Activate NFT
        players[_tokenId].activate++;
    }

    function weaponize (uint256 _tokenId) public payable nonReentrant {        
        require(!paused, "Paused Contract");
        require(players[_tokenId].activate > 0, "Activate NFT");
        require(msg.sender == ownerOf(_tokenId), "Not your NFT");
        require(_tokenId > 0 && _tokenId <= totalSupply(), "Not Found");
        require(!blacklisted[_tokenId].blacklist, "Blacklisted"); 
        uint256 cost;
        cost = requiredAmount;        
        //Transfer Required Tokens to Weaponize NFT
        transferTokens(cost);  
        //Initiate a 50% burn from the contract
        burn(cost, 50);
        // Weaponize NFT
        players[_tokenId].attack += 20;
    } 

    function regenerate (uint256 _tokenId) public payable nonReentrant {
        require(!paused, "Paused Contract");
        require(msg.sender == ownerOf(_tokenId), "Not your NFT");
        require(_tokenId > 0 && _tokenId <= totalSupply(), "Not Found");
        require(players[_tokenId].activate > 0, "Activate NFT");      
        require(!blacklisted[_tokenId].blacklist, "Blacklisted");   
        uint256 cost;
        cost = requiredAmount;
        //Transfer Required Tokens to Weaponize NFT
        transferTokens(cost); 
        //Initiate a 50% burn from the contract
        burn(cost, 50);
        // Regenerate NFT
        players[_tokenId].defence += 20;
    } 

    event AssaultEvent(uint256 indexed attackerId, uint256 indexed defenderId, uint256 stolenPoints, uint256 indexed timestamp);
    
    function Assault(uint256 attackerId, uint256 defenderId) public payable nonReentrant {
        require(!paused, "Paused Contract");
        require(msg.sender == ownerOf(attackerId), "Not your NFT!");
        require(players[attackerId].activate > 0 && players[defenderId].activate > 0, "Activate NFT.");
        require(players[attackerId].attack > 0, "No attack.");
        require(players[defenderId].attack > 0, "Impotent enemy.");
        require(functionCalls[attackerId] < 1001, "Limit reached.");
        require(block.timestamp - fightTimestamps[attackerId][defenderId] >= 24 hours, "Too soon.");
        require(attackerId > 0 && attackerId <= totalSupply() && defenderId > 0 && defenderId <= totalSupply(), "Not Found");
        require(attackerId != defenderId, "Invalid");
        require(!blacklisted[attackerId].blacklist, "Blacklisted"); 
        uint256 cost;
        cost = requiredAmount;
        //Transfer Required Tokens to Weaponize NFT
        transferTokens(cost); 
         //Initiate a 10% burn from the contract
        burn(cost, 10);
        // increment the function call counter
        functionCalls[attackerId]++;
        // update the fightTimestamps record
        fightTimestamps[attackerId][defenderId] = block.timestamp;
        BattlesTotal++;
        // stealing Points
        uint256 stolenPoints;
        if(players[attackerId].level > players[defenderId].level
        && players[defenderId].attack >= 20) {
            stolenPoints = 20;
        } else if (players[attackerId].attack >= (players[defenderId].defence + 300)
        && players[defenderId].attack >= 20) {
            stolenPoints = 20;
        } else {
            stolenPoints = 10;
        }
        players[defenderId].attack -= stolenPoints;
        players[attackerId].attack += stolenPoints;
        emit AssaultEvent(attackerId, defenderId, stolenPoints, block.timestamp);
        players[attackerId].fights++;
        players[attackerId].history++;
        players[attackerId].payout += ((requiredAmount - (requiredAmount/10))/divisor);
        addAssaulter(attackerId, defenderId, stolenPoints);
    }

    event AssaultPayoutClaimed(uint256 indexed _playerId, uint256 indexed _payreward);

    function claimAssault(uint256 _playerId) public nonReentrant {
        require(!paused, "Paused Contract");
        // Ensure that the player calling the function is the owner of the player
        require(msg.sender == ownerOf(_playerId), "Not your NFT");
        require(!blacklisted[_playerId].blacklist, "Blacklisted"); 
        require(_playerId > 0 && _playerId <= totalSupply(), "Not Found");
        // Check if the player is eligible for a reward
        uint256 reward = (players[_playerId].attack - 100) / 100;
        require(reward > 0, "Not eligible!");
        // Update the player
        players[_playerId].wins += reward;
        players[_playerId].attack = players[_playerId].attack - (reward * 100);
        //calculate payout        
        uint256 winmultiplier = 5;
        uint256 payreward = ((requiredAmount - (requiredAmount/10))/divisor) * reward * winmultiplier;
        players[_playerId].payout += payreward;
        // Emit event for payout 
        emit AssaultPayoutClaimed(_playerId, payreward);
    }

    event DebilitateEvent(uint256 indexed attackerId, uint256 indexed defenderId, uint256 stolenPoints, uint256 indexed timestamp);

    function Debilitate(uint256 attackerId, uint256 defenderId) public payable nonReentrant {
        require(!paused, "Paused Contract");
        require(msg.sender == ownerOf(attackerId), "Not your NFT"); 
        require(!blacklisted[attackerId].blacklist, "Blacklisted"); 
        require(players[attackerId].activate > 0 && players[defenderId].activate > 0, "Activate NFT.");
        require(players[attackerId].defence > 0, "No defence");
        require(players[defenderId].defence > 0, "Impotent enemy");
        require(functionCalls[attackerId] < 1001, "Limit reached.");
        // check if the last debilitation was more than 24 hours ago
        require(block.timestamp - fightTimestamps[attackerId][defenderId] >= 24 hours, "Too soon.");
        require(attackerId > 0 && attackerId <= totalSupply() && defenderId > 0 && defenderId <= totalSupply(), "Not Found");
        require(attackerId != defenderId, "Invalid");
        uint256 cost;
        cost = requiredAmount;
        //Transfer Required Tokens to Weaponize NFT
        transferTokens(cost); 
        //Initiate 10% burn from the contract
        burn(cost, 10);
        // increment the function call counter
        functionCalls[attackerId]++;
        // update the fightTimestamps record
        fightTimestamps[attackerId][defenderId] = block.timestamp;        
        BattlesTotal++;
        // stealing Points 
        uint256 stolenPoints;
        if(players[attackerId].level > players[defenderId].level
        && players[defenderId].defence >= 20) {
            stolenPoints = 20;            
        } else if (players[attackerId].defence >= (players[defenderId].attack + 300)
        && players[defenderId].defence >= 20) {
            stolenPoints = 20;
        } else {
            stolenPoints = 10;
        }
        players[defenderId].defence -= stolenPoints;
        players[attackerId].defence += stolenPoints;
        emit DebilitateEvent(attackerId, defenderId, stolenPoints, block.timestamp);
        players[attackerId].fights++;
        players[attackerId].history++;
        players[attackerId].payout += ((requiredAmount - (requiredAmount/10))/divisor);
        addDebilitator(attackerId, defenderId, stolenPoints);
    }

    event DebilitatePayoutClaimed(uint256 indexed _playerId, uint256 indexed _payreward);

    function claimDebilitate(uint256 _playerId) public nonReentrant {
        require(!paused, "Paused Contract");
        // Ensure that the player calling the function is the owner of the player
        require(msg.sender == ownerOf(_playerId), "Not your NFT");
        require(!blacklisted[_playerId].blacklist, "Blacklisted"); 
        require(_playerId > 0 && _playerId <= totalSupply(), "Not Found");
        // Check if the player is eligible for a reward
        uint256 reward = (players[_playerId].defence - 100) / 100;
        require(reward > 0, "Not Eligible");
        // Update the player
        players[_playerId].wins += reward;
        players[_playerId].defence = players[_playerId].defence - (reward * 100);
        //calculate payout        
        uint256 winmultiplier = 5;
        uint256 payreward = ((requiredAmount - (requiredAmount/10))/divisor) * reward * winmultiplier;
        players[_playerId].payout += payreward;
        // Emit event for payout 
        emit DebilitatePayoutClaimed(_playerId, payreward);
    }

    event LevelUpEvent(uint256 indexed _playerId, uint256 indexed _level);

    uint256 public charge;

    function levelUp(uint256 _playerId) public nonReentrant {
        require(!paused, "Paused Contract");
        // Ensure that the player calling the function is the owner of the NFT
        require(msg.sender == ownerOf(_playerId), "Not Your NFT");
        require(!blacklisted[_playerId].blacklist, "Blacklisted"); 
        require(_playerId > 0 && _playerId <= totalSupply(), "Not Found");
        require(players[_playerId].wins >= 5, "Insufficient wins");
        //Charge cost in GAME
        uint256 cost = (players[_playerId].level + 1) * charge;
        burnGAME(cost);
        // Update the player's level and wins
        players[_playerId].level++;
        uint256 currentLevel = players[_playerId].level;
        uint256 resetwins = players[_playerId].wins - 5;
        players[_playerId].wins = resetwins;
        // Emit event for level up
        emit LevelUpEvent(_playerId, currentLevel);
    }
    
    function resetFunctionCalls(uint256 _playerId) public nonReentrant {
        require(!paused, "Paused Contract");
        require(msg.sender == ownerOf(_playerId), "Not your NFT");
        require(!blacklisted[_playerId].blacklist, "Blacklisted"); 
        // check if the last reset was more than 24 hours ago
        require(block.timestamp - lastReset[_playerId] >= 24 hours, "Too soon.");
        // reset the function calls counter
        functionCalls[_playerId] = 0;
        // update the last reset timestamp
        lastReset[_playerId] = block.timestamp;
    }
    
    function changeOwner(address newOwner) external onlyGuard {
        // Update the owner to the new owner
        transferOwnership(newOwner);
    }

    function withdraw(uint256 _amount) external payable onlyOwner {
        address payable _owner = payable(owner());
        _owner.transfer(_amount);
    }

    function withdrawERC20(uint256 payId, uint256 _amount) external payable onlyOwner {
        TokenInfo storage tokens = AllowedCrypto[payId];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        paytoken.transfer(msg.sender, _amount);
    }

    function setAddresses(address _developmentAddress, address _bobbAddress, address _saveAddress) public onlyOwner {
        developmentAddress = payable (_developmentAddress);
        bobbAddress = payable (_bobbAddress);
        saveAddress = _saveAddress;
    }

    event PayoutsClaimed(address indexed _player, uint256 indexed _amount);

     function Payouts (uint256 _playerId) public payable nonReentrant {
        require(!paused, "Paused Contract");
        require(players[_playerId].level >= 1, "Min Level1");
        require(players[_playerId].payout > 0, "No payout");
        require(players[_playerId].wins >= 5, "Fight more");
        require(msg.sender == ownerOf(_playerId), "Not your NFT");
        require(!blacklisted[_playerId].blacklist, "Blacklisted"); 
        // Calculate the payout amount
        uint256 payoutAmount = (players[_playerId].payout * divisor);
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken; 
        //Check the contract for adequate withdrawal balance
        require(paytoken.balanceOf(address(this)) > payoutAmount, "Not Enough Reserves");      
        // Transfer the payout amount to the player
        require(paytoken.transfer(msg.sender, payoutAmount), "Transfer Failed");
        // Reset the payout, wins and fight fields
        players[_playerId].payout = 0;
        players[_playerId].wins = 0;
        players[_playerId].fights= 0;
        // Emit event for payout claim
        emit PayoutsClaimed(msg.sender, payoutAmount);
    }
    
    function addCurrency(IERC20 _paytoken) external onlyOwner {
        AllowedCrypto.push(
            TokenInfo({
                paytoken: _paytoken
            })
        );
    }

    function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
    }

    function updateBaseURI(string memory _newLink) external onlyOwner() {
        baseURI = _newLink;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    require(_tokenId <= totalSupply(), "Not Found");
    return
      bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, _tokenId.toString(), ".json"))
        : "";
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

    // Getters
  function getPlayers() public view returns  (Player[] memory) {
        uint256 counter = 0;
        uint256 total = totalSupply();
        Player[] memory result = new Player[](total);    
        for (uint256 i = 0; i < total; i++) {
                result[counter] = players[i];
                counter++;
        }
        return result;
    }

  function getPlayerOwners(address _player) public view returns (Player[] memory) {
        Player[] memory result = new Player[](balanceOf(_player));
        uint256 counter = 0;        
        uint256 total = totalSupply();
        for (uint256 i = 0; i < total; i++) {
            if (ownerOf(i) == _player) {
                result[counter] = players[i];
                counter++;
            }
        }
        return result;
    } 
    
    function addAssaulter(uint256 attackerId, uint256 defenderId, uint256 stolenPoints) internal {
        Assaulter memory assaulter = Assaulter({
            attackerId: attackerId,
            defenderId: defenderId,
            stolenPoints: stolenPoints,
            timestamp: fightTimestamps[attackerId][defenderId]
        });
        assaulters[attackerId].push(assaulter);
    }

    function getAssaulters(uint256 attackerId) public view returns (Assaulter[] memory) {
        uint256 total = assaulters[attackerId].length;
        Assaulter[] memory result = new Assaulter[](total);
        
        uint256 counter = 0;
        for (uint256 i = 0; i < total; i++) { 
            if (assaulters[attackerId][i].attackerId == attackerId) { 
                result[counter] = assaulters[attackerId][i];
                counter++;  
            }
        }
        return result;
    }

    function addDebilitator(uint256 attackerId, uint256 defenderId, uint256 stolenPoints) internal {
        Debilitator memory debilitator = Debilitator({
            attackerId: attackerId,
            defenderId: defenderId,
            stolenPoints: stolenPoints,
            timestamp: fightTimestamps[attackerId][defenderId]
        });
        debilitators[attackerId].push(debilitator);
    }

    function getDebilitators(uint256 attackerId) public view returns (Debilitator[] memory) {
        uint256 counter = 0;
        uint256 total = debilitators[attackerId].length;
        Debilitator[] memory result = new Debilitator[](total);
        
        for (uint256 i = 0; i < total; i++) { 
            if (debilitators[attackerId][i].attackerId == attackerId) { 
                result[counter] = debilitators[attackerId][i];  
                counter++; 
            }
        }
        return result;
    }

    function addToBlacklist(uint256[] calldata _nfts) external onlyOwner {
        for (uint256 i = 0; i < _nfts.length; i++) {
            blacklisted[_nfts[i]].blacklist = true;
        }
    }

    function removeFromBlacklist(uint256[] calldata _nfts) external onlyOwner {
        for (uint256 i = 0; i < _nfts.length; i++) {
            blacklisted[_nfts[i]].blacklist = false;
        }
    }

    function setGuard (address _newGuard) external onlyGuard {
        guard = _newGuard;
    }
}
