pragma solidity ^0.4.21;


// delegatecall: allows the called function of external contract to modify the caller's storage
// expect different storage values after return
// possible security issue? owner of both contracts must be same
// msg.sender is preserved : the msg.sender of the caller is the same as that of msg.sender in the caller


// this contract is not complete, just used to test external function calls
contract TokenOrigin {
    mapping (address => mapping(uint256 => uint256)) public balances; // address => token ID => balance
    mapping(uint256 => uint256) public inCirculation; // token ID => amount in circulation
    address myAddress = address(this);
    address owner;
    
    function TokenOrigin() {
        owner = msg.sender;
    }
    
    function addToCirc(uint256 _token, uint256 _value) public returns (uint256) {
        inCirculation[_token] += _value;
        balances[myAddress][_token] += _value;
        return inCirculation[_token];
    }
    
    function addBalance(uint256 _a, uint256 _token, uint256 _value) public returns (uint256) {
        address _addr = address(_a); // cast input uint(address) back into address
        balances[_addr][_token] += _value;
        inCirculation[_token] += _value;
        return balances[_addr][_token];
    }
}

// issue with call function: arguments have to be (padded to) 32 bytes
contract TokenTransfer {
    
    // calls addToCirc in TokenOrigin
    // issue: changing _token from uint256 to uint32 causes the call function to not work
    // delegatecall likely the same
    // call only takes 32 byte arguments
    function delegateCallAddToCirculation (address _contract, uint256 _token, uint256 _value) public returns (uint256 ans) {
        //TokenOrigin addr = TokenOrigin(_contract);
        //address addr = address(t);
        bytes4 sig = bytes4(keccak256("addToCirc(uint256,uint256)")); // function signature
        
        assembly {
            // free memory pointer : 0x40
            let x := mload(0x40) // get empty storage location
            mstore ( x, sig ) // 4 bytes - place signature in empty storage
            mstore (add(x, 0x04), _token) // uint32 : 4 bytes
            mstore (add(x, 0x24), _value) // uint256 : 32 bytes
            
            // if successful, ret = 1, else ret = 0
            let ret := delegatecall (gas, 
                _contract,
                x, // input
                0x44, // input size = 32 + 4 + 4 bytes
                x, // output stored at input location, save space
                0x20 // output size = 32 bytes
            )
                
            ans := mload(x)
            mstore(0x40, add(x,0x20)) // update free memory pointer
        }       
    }
    
    // issue: keccak256 sig doesn't seem to take addresses correctly
    // possible fix: cast _addr as uint, pass uint(_addr) into TokenOrigin.addBalance, 
    // convert back to address in TokenOrigin.addBalance
    function callAddBalance(address _contract, address _addr, uint256 _token, uint256 _value) public returns (uint256 ans) {
        //TokenOrigin t = TokenOrigin(_contract);
        //address addr = address(t);
        bytes4 sig = bytes4(keccak256("addBalance(uint256,uint256,uint256)")); // function signature
        uint256 castedAddr = uint256(_addr); 
        
        assembly {
            // free memory pointer : 0x40
            let x := mload(0x40) // get empty storage location
            mstore ( x, sig ) // 4 bytes - place signature in empty storage
            mstore (add(x, 0x04), castedAddr ) // 32 byte uint32(address) - placed after signature
            mstore (add(x, 0x24), _token) // 32 bytes
            mstore (add(x, 0x44), _value) // 32 bytes
            
            // if successful, ret = 1, else ret = 0
            let ret := call (gas, 
                _contract,
                0, // no wei passed to function
                x, // input
                0x64, // input size = 32 + 32 + 32 + 4 bytes
                x, // output stored at input location, save space
                0x20 // output size = 32 bytes
            )
                
            ans := mload(x)
            mstore(0x40, add(x,0x20)) // update free memory pointer
        }
    }
    
    function addressToBytes(address a) public pure returns (bytes b){
        assembly {
            let m := mload(0x40) // free space pointer
            mstore(add(m, 20), // offset m + 32bytes
                xor(0x140000000000000000000000000000000000000000, a) // xor with 20 ones followed by zeroes 
                )                                                    
            mstore(0x40, add(m, 52)) // update free mem pointer : m + 32 bytes + 20 bytes
            b := m
        }
    }
    
    // eg. b = 000..000abc123def : padded to 32 bytes
    //      b[0] = ef
    //      b[1] = 3d
    //      ...
    //      b[32] = 00
    // DOES NOT WORK 
    function bytesToByte32(bytes b) public pure returns (bytes32){
        bytes32 ret;
        for (uint i = 0; i < 32; i++){
            ret |= bytes32(b[i]) >> (i * 8); // ret is bitwise or-ed with each byte of b (left/right?) shifted 
        }
        return ret;
    }
    
    // not tested
    function bytesToAddress(bytes _address) public pure returns (address) {
        uint160 m = 0;
        uint160 b = 0;
        for (uint8 i = 0; i < 20; i++) {
            m *= 256;
            b = uint160(_address[i]);
            m += (b);
        }
        return address(m);
    }
}