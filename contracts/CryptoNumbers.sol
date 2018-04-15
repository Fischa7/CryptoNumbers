pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";

contract CryptoNumbers is Ownable, ERC721Token("CryptoNumbers","CN") {
    
    using SafeMath for uint256; 

    struct Number {
        uint64 birthtime;
        uint64 cooldownEndblock;
    }

    // initial price for minting a new number
    uint256 internal price = 1 finney;
    uint256 internal addFee = 1 finney;

    // for later implementation of auctioning the numbers
    uint256 public constant NO_STARTING_PRICE = 1 finney;

    // number that is currently being sold. starts at 0
    uint256 internal nextToBeMinted_ = 0;

    function setPrice(uint256 _price) external onlyOwner() {
        price = _price;
    }
             
    /// mints the next available number. Each number can only be minted once.
    function mintNext() public payable {
        require(msg.value >= price);
        uint256 numId = getNextToBeMinted();
        _mint(msg.sender, numId);
        nextToBeMinted_ = nextToBeMinted_.add(1);

        // in case the user sent to much money, send the rest of it back
        if (msg.value > price) {
            uint256 excess = msg.value.sub(price);
            msg.sender.transfer(excess);
        }
    }

    function mintAddition(uint256 numId1, uint256 numId2) public payable {
        // TODO: require, check if both numbers are allowed to reproduce
        require(msg.value >= addFee); 
        uint256 newNumId;
        newNumId = numId1 + numId2;
        // the new number must not exist already
        require(!exists(newNumId));
        _mint(msg.sender, numId1.add(numId2));
        
        // in case the user sent to much money, send the rest of it back
        if (msg.value > price) {
            uint256 excess = msg.value.sub(price);
            msg.sender.transfer(excess);
        }
    }


    // displays the next number to be minted. 
    function showNextToBeMinted() public view returns(uint256) {
        return nextToBeMinted_;
    }

    // gets the next number to be minted. 
    function getNextToBeMinted() public returns (uint256) {
        while(exists(nextToBeMinted_)) {
            nextToBeMinted_ = nextToBeMinted_.add(1);
        }
        return nextToBeMinted_;
    }
}