// SPDX-License-Identifier: MIT

// @title GAME token for battledogs Arena
// https://twitter.com/0xSorcerers | https://github.com/Dark-Viper | https://t.me/Oxsorcerer | https://t.me/battousainakamoto | https://t.me/darcViper

pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GAME is ERC20, Ownable, ReentrancyGuard {        
        constructor(string memory _name, string memory _symbol, address _newGuard, address _devWallet, address _lpWallet, address _deadWallet) 
            ERC20(_name, _symbol)
        {
        guard = _newGuard;       
        devWallet = _devWallet;
        lpWallet = _lpWallet;
        deadWallet = _deadWallet;
        _mint(msg.sender, MAX_SUPPLY);  

        }
    using ABDKMath64x64 for uint256;
    using SafeMath for uint256;

    address public burnercontract;
    
    bool public paused = false;
    address private guard;
    uint256 public MAX_SUPPLY = 5000000000 * 10 ** decimals();
    uint256 public TotalBurns;

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    modifier onlyBurner() {
        require(msg.sender == burnercontract, "Not authorized.");
        _;
    }

    event burnEvent(uint256 indexed _amount);
    function Burn(uint256 _amount) external onlyBurner {                
       require(!paused, "Paused Contract");
       _burn(msg.sender, _amount);
       TotalBurns += _amount;
       emit burnEvent(_amount);
    }

    function Burner(uint256 _amount) external onlyOwner {                
        require(!paused, "Paused Contract");
       _burn(msg.sender, _amount);
       TotalBurns += _amount;
       emit burnEvent(_amount);
    }

    event Pause();
    function pause() public onlyGuard {
        require(!paused, "Contract already paused.");
        paused = true;
        emit Pause();
    }

    event Unpause();
    function unpause() public onlyGuard {
        require(msg.sender == owner(), "Only Deployer.");
        require(paused, "Contract not paused.");
        paused = false;
        emit Unpause();
    }

    /**
     * @dev sets wallets tax is sent to.
     */
    function setWallets (address _lpwallet, address _devWallet, address _deadWallet) external onlyOwner {
        lpWallet = _lpwallet;
        devWallet = _devWallet;
        deadWallet = _deadWallet;
    }

    function setBurner (address _burner) external onlyOwner {
        burnercontract = _burner;
    }

    function setGuard (address _newGuard) external onlyGuard {
        guard = _newGuard;
    }
}
