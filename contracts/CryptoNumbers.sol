pragma solidity ^0.4.22;

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
    uint256 internal price = 1 szabo;
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

contract NumberSaleBase {
    
    using SafeMath for uint256; 

    struct Sale {
        // seller of the number
        address seller;
        // price set from the seller
        uint128 price;
        // Time when sale started
        // NOTE: 0 if this sale has been concluded
        uint64 startedAt;
    }

    ERC721Token public nfContract;
    uint256 public ownerCut;

    mapping (uint256 => Sale) tokenIdToSale;

    event SaleCreated(uint256 tokenId, uint256 price);
    event SaleSuccessful(uint256 tokenId, uint256 price, address buyer);
    event SaleCancelled(uint256 tokenId);

    // checks wether or not the user actually owns the token
    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return (nfContract.ownerOf(_tokenId) == _claimant);
    }

    // transfers token to the contract
    function _escrow(address _owner, uint256 _tokenId) internal {
        nfContract.transferFrom(_owner, this, _tokenId);
    }

    // transfers token to _receiver
    function _transfer(address _receiver, uint256 _tokenId) internal {
        nfContract.transferFrom(this, _receiver, _tokenId);
    }

    // removes sale from mapping
    function _removeSale(uint256 _tokenId) internal {
        delete tokenIdToSale[_tokenId];
    }
    
    // checks if is on sale
    function _isOnSale(Sale storage _sale) internal view returns(bool) {
        return(_sale.startedAt > 0);
    }

    // adds a new sale for the specified token
    function _addSale(uint256 _tokenId, Sale _sale) internal {
        tokenIdToSale[_tokenId] = _sale;

        emit SaleCreated(
            uint256(_tokenId),
            uint256(_sale.price)
        );
    }

    // cancels an existing sale
    function _cancelSale(uint256 _tokenId, address _seller) internal {
        _removeSale(_tokenId);
        _transfer(_seller, _tokenId);
        emit SaleCancelled(_tokenId);
    }

    // transfers money, does NOT transfer token yet.
    function _buy(uint256 _tokenId, uint256 _amount) internal returns(uint256) {
        Sale storage sale = tokenIdToSale[_tokenId];
        
        require(_isOnSale(sale));
        
        require(_amount >= sale.price);

        address seller = sale.seller;

        _removeSale(_tokenId);

        if (sale.price > 0) {
            uint256 auctioneerCut = _computeCut(sale.price);
            uint256 sellerProceeds = sale.price - auctioneerCut;

            seller.transfer(sellerProceeds);
        }

        uint256 bidExcess = _amount - sale.price;
        msg.sender.transfer(bidExcess);

        emit SaleSuccessful(_tokenId, sale.price, msg.sender);
        return sale.price;
    }

    // calculates the cut from the price
    function _computeCut(uint256 _price) internal view returns(uint256) {
        return _price.mul(ownerCut).div(1000);
    }
}

contract NumberSale is NumberSaleBase, Ownable {
    
    constructor(address _nftAddress, uint256 _cut) public {
        require(_cut <= 1000);
        ownerCut = _cut;
        nfContract = ERC721Token(_nftAddress);
    }

    function withdrawBalance() external {
        address nftAddress = address(nfContract);

        require(msg.sender == owner || msg.sender == nftAddress);
        bool res = nftAddress.send(this.balance);
    }

    function createSale(
        uint256 _tokenId,
        uint256 _price,
        address _seller
    )
    external {
        // check that there are no overflows
        require(_price == uint256(uint128(_price)));
        require(_owns(msg.sender,_tokenId));
        _escrow(msg.sender, _tokenId);
        Sale memory sale = Sale(
            _seller,
            uint128(_price),
            uint64(now)
        );
        _addSale(_tokenId, sale);
    }

}