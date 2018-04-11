pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";

contract CryptoNumbers is Ownable, ERC721Token("CryptoNumbers","CN") {
    
    using SafeMath for uint256;
    // initial price for minting a new number
    uint256 internal price = 1 finney;
    // for later implementation of auctioning the numbers
    uint256 public constant NO_STARTING_PRICE = 1 finney;

    function setPrice(uint256 _price) external onlyOwner() {
        price = _price;
    }
    
    /// mints a new number. Each number can only be minted once.
    function mint(uint256 numId) public payable {
        require(msg.value >= price);
        _mint(msg.sender, numId);

        // in case the user send to much money, send the rest of it back
        if (msg.value > price) {
            uint256 excess = msg.value.sub(price);
            msg.sender.transfer(excess);
        }
    }
}