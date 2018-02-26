pragma solidity ^0.4.18;


contract CryptoCarzControl {

    address public owner;
    address public manager;
    bool public paused = false;

    event SetOwner(address indexed previousOwner, address indexed newOwner);
    event SetManager(address indexed previousManager, address indexed newManager);


    // control access

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }

    modifier onlyControl() {
        require(
            msg.sender == owner ||
            msg.sender == manager
        );
        _;
    }

    function CryptoCarzControl() public {
        owner = msg.sender;
    }

    function setOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        SetOwner(owner, _newOwner);
        owner = _newOwner;
    }

    function setManager(address _newManager) external onlyOwner {
        require(_newManager != address(0));
        SetManager(manager, _newManager);
        manager = _newManager;
    }


    // pausing

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused() {
        require(paused);
        _;
    }

    function pause() external onlyControl whenNotPaused {
        paused = true;
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
    }
}