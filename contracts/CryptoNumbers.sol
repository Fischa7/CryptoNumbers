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

    // for later implementation of auctioning the numbers
    uint256 public constant NO_STARTING_PRICE = 1 finney;

    // number that is currently being sold. starts at 0
    uint256 internal nextToBeMinted_ = 0;

    function setPrice(uint256 _price) external onlyOwner() {
        price = _price;
    }
    
    /// mints the next available number. Each number can only be minted once.
    function mint() public payable {
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

    // displays the next number to be minted. 
    function showNextToBeMinted() public view returns(uint256) {
        return nextToBeMinted_;
    }

    // gets the next number to be minted. 
    function getNextToBeMinted() public returns (uint256) {
        for (uint256 i = 0; i < 10; i.add(1)) {
            nextToBeMinted_= nextToBeMinted_.add(1);
        }
        return nextToBeMinted_;
    }
}