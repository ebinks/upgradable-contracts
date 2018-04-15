pragma solidity ^0.4.21;

// backwards compatibility of contracts: simple to do as long as oldContract has get/set functions for its 
// storage vars
// use delegatecall in newContract to use functions of oldContract
//
// forwards compatibility: not as simple
// could deploy oldContract with pre-created delegatecall functions that specify function names and params
// for a future contract
// issue: limited number of future contract functions that can be accessed
// possible fix: pass in the new contract's function signature to a delegatecall function in oldContract
// still fixed number of parameters due to assembly code, can be ok if just upgrading an old function
//
// upgradability suggestions:
// 1. storage saved in original or separate storage contract; no large data transfers
// 2. use of an interface that stores function signatures; when we upgrade a function, make sure it has
//    same name and parameters; simplifies upgrades that don't change interface of contract
// 3. to add new functions, probably want to go with idea above of passing in a new function signature to 
//    pre-created function that performs a delegatecall to new function
// 4. encapsulate logic in "libraries"


contract DelegateCall {
    mapping (address => uint) public balance;
    mapping (address => mapping(uint256 => uint256)) public balances; // address => token ID => balance
    address public myAddr = address(this);
    address public caller;
    
    function delegateCallUpdateBalance(address _contract, address _addr, uint256 _value) public returns (uint n) {
        caller = msg.sender;
        
        bytes4 sig = bytes4(keccak256("updateBalance(uint256,uint256)")); // function signature
        uint256 _castedAddr = uint256(_addr); // might be unneeded
        uint ans; 
        
        assembly {
            // free memory pointer : 0x40
            let x := mload(0x40) // get empty storage location
            mstore ( x, sig ) // 4 bytes - place signature in empty storage
            
            //mstore (add(x,0x04), zeroes) // pad with 1 word of zeroes
            mstore (add(x, 0x04), _castedAddr) // uint256 : 32 bytes
            mstore (add(x, 0x24), _value) // uint256 : 32 bytes
            
            // if successful, ret = 1, else ret = 0
            let ret := delegatecall(gas, 
                _contract,
                x, // input
                0x44, // input size = 32 + 4 + 4 bytes
                x, // output stored at input location, save space
                0x20 // output size = 32 bytes
            )
            
                
            ans := mload(x)
            mstore(0x40, add(x,0x20)) // update free memory pointer
        }    
        n = ans;
    }
    
    function delegateCallUpdateBalanceOfToken(address _contract, address _addr, uint256 _token, uint256 _value) public returns (uint n) {
        bytes4 sig = bytes4(keccak256("updateBalanceOfToken(uint256,uint256,uint256)")); // function signature
        uint256 _castedAddr = uint256(_addr); // might be unneeded
        uint ans; 
        
        assembly {
            // free memory pointer : 0x40
            let x := mload(0x40) // get empty storage location
            mstore ( x, sig ) // 4 bytes - place signature in empty storage
            mstore (add(x, 0x04), _castedAddr) // uint256 : 32 bytes
            mstore (add(x, 0x24), _token) // uint256 : 32 bytes
            mstore (add(x, 0x44), _value) // uint256 : 32 bytes
        
            // if successful, ret = 1, else ret = 0
            let ret := delegatecall(gas, 
                _contract,
                x, // input
                0x64, // input size = 32 + 4 + 4 bytes
                x, // output stored at input location, save space
                0x20 // output size = 32 bytes
            )
                
            ans := mload(x)
            mstore(0x40, add(x,0x20)) // update free memory pointer
        }    
        n = ans;
    }
}


// acts as "library" 
// changing local variables in this contract simultaneously changes the variables in the main contract
// when you delegatecall a function in this contract from main contract, it appears that the function you have called
// is now part of the main contract, and it has access to all storage and functions in the main contract
// storage in this contract never actually gets set
contract TokenHelper {
    mapping (address => uint) public balance;
    mapping (address => mapping(uint256 => uint256)) public balances; // address => token ID => balance
    address public myAddr;
    address public caller;

    function updateBalance(uint256 _addr, uint256 _value) public {
        balance[address(_addr)] = _value;
        myAddr = address(this); // this does not change myAddr in main contract : address(this) inside helper is same as inside main
        caller = msg.sender; // same msg.sender in caller and called contract
    }
    
    function updateBalanceOfToken(uint256 _addr, uint256 _token, uint256 _value) public {
        balances[address(_addr)][_token] = _value;
    }
    
    function getBalance(address _addr) public view returns (uint256) {
        return balance[_addr];
    }
}