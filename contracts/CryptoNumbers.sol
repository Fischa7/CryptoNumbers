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

contract ClockAuctionBase {
    
    using SafeMath for uint256; 

    struct Auction {
        // seller of the number
        address seller;
        // price set from the seller
        uint128 price;
        // Time when auction started
        // NOTE: 0 if this auction has been concluded
        uint64 startedAt;
    }

    ERC721Token public nfContract;
    uint256 public ownerCut;

    mapping (uint256 => Auction) tokenIdToAuction;

    event AuctionCreated(uint256 tokenId, uint256 price);
    event AuctionSuccessful(uint256 tokenId, uint256 price, address buyer);
    event AuctionCancelled(uint256 tokenId);

    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return (nfContract.ownerOf(_tokenId) == _claimant);
    }

    function _escrow(address _owner, uint256 _tokenId) internal {
        nfContract.transferFrom(_owner, this, _tokenId);
    }

    function _transfer(address _receiver, uint256 _tokenId) internal {
        nfContract.transferFrom(this, _receiver, _tokenId);
    }

    function _removeAuction(uint256 _tokenId) internal {
        delete tokenIdToAuction[_tokenId];
    }
    
    function _isOnAuction(Auction storage _auction) internal view returns(bool) {
        return(_auction.startedAt > 0);
    }

    function _addAuction(uint256 _tokenId, Auction _auction) internal {
        tokenIdToAuction[_tokenId] = _auction;

        emit AuctionCreated(
            uint256(_tokenId),
            uint256(_auction.price)
        );
    }

    function _cancelAuction(uint256 _tokenId, address _seller) internal {
        _removeAuction(_tokenId);
        _transfer(_seller, _tokenId);
        emit AuctionCancelled(_tokenId);
    }

    function _buy(uint256 _tokenId, uint256 _amount) internal returns(uint256) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        
        require(_isOnAuction(auction));
        
        require(_amount >= auction.price);

        address seller = auction.seller;

        _removeAuction(_tokenId);

        if (auction.price > 0) {
            uint256 auctioneerCut = _computeCut(auction.price);
            uint256 sellerProceeds = auction.price - auctioneerCut;

            seller.transfer(sellerProceeds);
        }

        uint256 bidExcess = _amount - auction.price;
        msg.sender.transfer(bidExcess);

        emit AuctionSuccessful(_tokenId, auction.price, msg.sender);
        return auction.price;
    }

    function _computeCut(uint256 _price) internal view returns(uint256) {
        return _price.mul(ownerCut).div(1000);
    }
}