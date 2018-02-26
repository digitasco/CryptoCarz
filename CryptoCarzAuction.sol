pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";
import './CryptoCarzToken.sol';
import './CryptoCarzControl.sol';


contract CryptoCarzAuction is CryptoCarzControl {

    using SafeMath for uint256;

    uint256[] public carIds;
    uint256 public auctionEndTime;
    CryptoCarzToken public token;
    uint256 public maxNumWinners;

    mapping(address => uint256) public bids;
    address[] public bidders;
    uint256[] public sortedBids;
    mapping(address => bool) public winners;
    uint256 public numWinners;
    bool public cancelled;

    uint256 public carPrice;
    bool public carsAssigned = false;
    uint256 public numCarsTransferred = 0;
    mapping(address => bool) public carClaimed;


    // events
    
    event NewAuction(address auction, uint256[] carIds, uint256 auctionEndTime, uint256 maxNumWinners);
    event NewBid(address bidder, uint256 amount);
    event UpdateBid(address bidder, uint256 amount);
    event CancelBid(address winner, uint256 amount);
    event AuctionExtended(uint256 auctionEndTime);
    event Winner(address winner);
    event CarsAssigned();
    event CarClaimed(address claimer, uint256 carId);
    event Withdrawal();
    event AuctionCancelled();
    event Refund(address bidder, uint256 amount);
    event DebugEvent(string stuff, uint256 stuff2);
    event DebugEventAddress(string stuff, address stuff2);
    

    // modifiers

    modifier beforeAuctionEndTime() {
        require(now < auctionEndTime);
        _;
    }

    modifier afterAuctionEndTime() {
        require(now >= auctionEndTime);
        _;
    }

    modifier ifNotCancelled() {
        require(!cancelled);
        _;
    }

    modifier ifCancelled() {
        require(cancelled);
        _;
    }    

    modifier onlyBeforeCarsAssigned() {
        require(!carsAssigned);
        _;
    }    

    modifier onlyAfterCarsAssigned() {
        require(carsAssigned);
        _;
    }

    modifier onlyWinners() {
        require(winners[msg.sender]);
        _;
    }

    modifier onlyLosers() {
        require(!winners[msg.sender]);
        _;
    }


    // functions

    function CryptoCarzAuction(address _manager, address _token, uint256[] _carIds, uint256 _biddingTime, uint256 _maxNumWinners) public {
        manager = _manager;
        token = CryptoCarzToken(_token);
        carIds = _carIds;
        auctionEndTime = now + _biddingTime;
        maxNumWinners = _maxNumWinners;
        NewAuction(this, _carIds, auctionEndTime, maxNumWinners);
    }

    function extendAuction(uint256 _extraBiddingTime) public onlyManager beforeAuctionEndTime ifNotCancelled {
        auctionEndTime += _extraBiddingTime;
        AuctionExtended(auctionEndTime);
    }

    function cancelAuction() public onlyManager ifNotCancelled onlyBeforeCarsAssigned {
        cancelled = true;
        AuctionCancelled();
    }    

    function bid() public payable beforeAuctionEndTime ifNotCancelled whenNotPaused {
        uint256 currentAmount = bids[msg.sender];
        bids[msg.sender] = currentAmount.add(msg.value);

        if (currentAmount > 0) {
            UpdateBid(msg.sender, bids[msg.sender]);
        } else {
            bidders.push(msg.sender);            
            NewBid(msg.sender, bids[msg.sender]);
        }
    }

    function getCarIds() public constant returns (uint256[]) {
        return carIds;
    }

    function getBidders() public constant returns (address[]) {
        return bidders;
    }

    function getBidderAmount(address _bidder) public constant returns (uint256) {
        return bids[_bidder];
    }

    function getSortedBids() public constant onlyAfterCarsAssigned returns (uint256[]) {
        return sortedBids;
    }    

    function getCarPrice() public constant onlyAfterCarsAssigned returns (uint256) {
        return carPrice;
    }    
    
    function isWinner(address bidder) public constant onlyAfterCarsAssigned returns (bool) {
        return winners[bidder];
    }
  
    function getBidAmounts() public constant returns (uint256[]) {
        uint256[] bidAmounts;
        for (uint256 i = 0; i < bidders.length; i++) {
            bidAmounts.push(bids[bidders[i]]);
        }
        return bidAmounts;
    }

    // @dev this function intendedly to be called by anyone, including one of the auctions winner
    function assignWinners() public afterAuctionEndTime onlyBeforeCarsAssigned ifNotCancelled whenNotPaused {

        for (uint256 i = 0; i < bidders.length; i++) {
            sortedBids.push(bids[bidders[i]]);
        }
        sort(sortedBids, bidders, 0);
        if (bidders.length < maxNumWinners) {
            numWinners = bidders.length;
        } else {
            numWinners = maxNumWinners;
        }
        for (i = 0; i < numWinners; i++) {
            winners[bidders[i]] = true;
            Winner(bidders[i]);
        }
        carPrice = sortedBids[numWinners - 1];
        carsAssigned = true;
    }    

    function sort(uint256[] storage arr, address[] storage arr2, uint256 left) internal {

        require(arr.length == arr2.length);

        while (left < arr.length-1) {
            uint256 i = left + 1;
            uint256 highestPriceIndex = i;
            uint256 highestPrice = arr[i];

            while (i < arr.length) {
                if (arr[i] > highestPrice) {
                    highestPriceIndex = i;
                    highestPrice = arr[i];
                }
                i++;
            }

            if (highestPrice > arr[left]) {
                arr[highestPriceIndex] = arr[left];
                arr[left] = highestPrice;
                address highestPrice2 = arr2[highestPriceIndex];
                arr2[highestPriceIndex] = arr2[left];
                arr2[left] = highestPrice2;
            }
            left++;
        }
    }
    
    function cancelBid() public onlyAfterCarsAssigned onlyLosers ifNotCancelled whenNotPaused {
        uint256 amount = bids[msg.sender];
        if (amount > 0) {
            bids[msg.sender] = 0; // prevent re-entrancy attack
            if (!msg.sender.send(amount)) {
                bids[msg.sender] = amount;
            }
            CancelBid(msg.sender, amount);
        }
    }
    
    function claimCar() public onlyWinners onlyAfterCarsAssigned ifNotCancelled whenNotPaused {
        require(numCarsTransferred < numWinners);
        require(!carClaimed[msg.sender]);
        uint carId = carIds[numCarsTransferred];
        token.transfer(msg.sender, carId);
        numCarsTransferred++;
        carClaimed[msg.sender] = true;
        CarClaimed(msg.sender, carId);
    }

    function withdraw() public onlyManager onlyAfterCarsAssigned whenNotPaused {
        for (uint256 i = 0; i < bidders.length; i++) {
            if (winners[bidders[i]]) {
                msg.sender.transfer(bids[bidders[i]]);
            }
        }
        Withdrawal();
    }

}

