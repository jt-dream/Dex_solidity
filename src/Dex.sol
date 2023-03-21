// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



contract ERC20test {
    //interface
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    //func
    constructor(
        string memory name_,
        string memory symbol_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals =18;
        _totalSupply = 0;

    }
    function name() public view returns (string memory){
        return _name;
    }
   
    function symbol() public view returns (string memory){
         return _symbol;
    }
    function decimals() public view returns (uint8){ 
        return _decimals;
    }
    function totalSupply() public virtual returns (uint256){ 
        return _totalSupply;
    }
    function balanceOf(address _owner) public virtual returns (uint256){
        return balances[_owner];
    }
    function transfer_(address _to, uint256 _value) external virtual returns (bool success){
        require(_to != address(0), "transfer to the zero address");
        require(balances[msg.sender] >= _value, "value exceeds balance");
        unchecked {
            balances[msg.sender] -= _value; balances[_to] += _value;    
        }
        emit Transfer(msg.sender, _to, _value); }
    function approve(address _spender, uint256 _value) public virtual returns (bool success){
        require(_spender != address(0), "approve to the zero address");
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); }
    function allowance(address _owner, address _spender) public view returns (uint256 remaining){ 
        return allowances[_owner][_spender];
    }
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success){ require(_from != address(0), "transfer from the zero address");
        require(_to != address(0), "transfer to the zero address");
        uint256 currentAllowance = allowance(_from, msg.sender); 
        if(currentAllowance != type(uint256).max){
        require(currentAllowance >= _value, "insufficient allowance"); 
            unchecked {
             allowances[_from][msg.sender] -= _value; 
            }
        }
        require(balances[_from] >= _value, "value exceeds balance");
            unchecked {
                balances[_from] -= _value; balances[_to] += _value;
        }
        emit Transfer(_from, _to, _value); 
}

function _mint(address _owner, uint256 _value) public { 
    require(_owner != address(0), "mint to the zero address"); 
    _totalSupply += _value;
unchecked {
    balances[_owner] += _value;
}
emit Transfer(address(0), _owner, _value);
}

function _burn(address _owner, uint256 _value) internal {
    require(_owner != address(0), "burn from the zero address"); 
    require(balances[_owner] >= _value, "burn amount exceeds balance"); 
    unchecked {
           balances[_owner] -= _value;
           _totalSupply -= _value;
       }
emit Transfer(_owner, address(0), _value);
}
}
contract Dex is ERC20test{
    ERC20test public tokenX;
    ERC20test public tokenY;

    uint256 public _amountX; // X 발행량
    uint256 public _amountY; // Y 발행량
    ERC20test public LPtoken;
    
    

constructor (address addrX, address addrY) ERC20test("LPToken","LPT"){
    tokenX = ERC20test(addrX);
    tokenY = ERC20test(addrY);
    LPtoken = ERC20test(address(this));

}   
function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
// tokenXAmount / tokenYAmount 중 하나는 무조건 0이어야 합니다. 수량이 0인 토큰으로 스왑됨.
    require(tokenXAmount == 0 || tokenYAmount == 0 ,"token is only one side 0");
    require(_amountX > 0 && _amountY > 0, "no token to swap");
    

    if(tokenYAmount == 0 ) {
        outputAmount = _amountY * (tokenXAmount * 999/1000) / (_amountX + (tokenXAmount*999/1000));

        require(outputAmount>=tokenMinimumOutputAmount,"output must be over min");
        _amountY -= outputAmount;
        _amountX += tokenXAmount;
        tokenX.transferFrom(msg.sender,address(this),tokenXAmount);
        tokenY.transfer_(msg.sender,outputAmount);
    }
    else {
         outputAmount = _amountX * (tokenYAmount * 999/1000) / (_amountY + (tokenYAmount*999/1000));

        require(outputAmount>=tokenMinimumOutputAmount,"output must be over min");
        _amountX -= outputAmount;
        _amountY += tokenXAmount;
        tokenY.transferFrom(msg.sender,address(this),tokenYAmount);
        tokenX.transfer_(msg.sender,outputAmount);
    }
}
function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external virtual returns (uint256 LPTokenAmount){
        require(tokenXAmount > 0, "Less TokenA Supply");
        require(tokenYAmount > 0, "Less TokenB Supply");
        require(tokenX.allowance(msg.sender, address(this)) >= tokenXAmount, "ERC20: insufficient allowance");
        require(tokenY.allowance(msg.sender, address(this)) >= tokenYAmount, "ERC20: insufficient allowance");
        require(tokenX.balanceOf(msg.sender) >= tokenXAmount, "ERC20: transfer amount exceeds balance");
        require(tokenY.balanceOf(msg.sender) >= tokenYAmount, "ERC20: transfer amount exceeds balance");
        _amountX = tokenX.balanceOf(address(this));
        _amountY = tokenY.balanceOf(address(this));
        uint256 totalsupply_ = totalSupply();
        
        if (totalsupply_ == 0){
            LPTokenAmount = sqrt(tokenXAmount * tokenYAmount) ;
        }
        else{ 
            uint256 amountX = tokenXAmount * totalsupply_ / tokenX.balanceOf(address(this));
            uint256 amountY = tokenYAmount * totalsupply_ / tokenY.balanceOf(address(this));
            LPTokenAmount = (amountX < amountY) ? amountX : amountY;
    }
     require(LPTokenAmount >= minimumLPTokenAmount, "Less LP Token Supply");

    _mint(msg.sender, LPTokenAmount);
    
    tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
    tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
    
    return LPTokenAmount;
}
function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns (uint tokenXAmount,uint tokenYAmount){
    require(LPTokenAmount > 0, "Less LP Token Supply");
    require(LPtoken.balanceOf(msg.sender) >= LPTokenAmount, "Insufficient LP Token balance");
    
    uint256 totalSupply_ = ERC20test(address(this)).totalSupply();
    uint256 tokenXAmount = _amountX * LPTokenAmount / totalSupply_;
    uint256 tokenYAmount = _amountY * LPTokenAmount / totalSupply_;
    
    require(tokenXAmount >= minimumTokenXAmount, "TokenX amount below minimum");
    require(tokenYAmount >= minimumTokenYAmount, "TokenY amount below minimum");
    
    unchecked {
        _amountX -= tokenXAmount;
        _amountY -= tokenYAmount;
    }
    
    LPtoken.transferFrom(msg.sender, address(this), LPTokenAmount);
    tokenX.transfer_(msg.sender, tokenXAmount);
    tokenY.transfer_(msg.sender, tokenYAmount);
    
    
}
function sqrt(uint x) public returns (uint y) {
    uint z = (x + 1) / 2;
    y = x;
    while (z < y) {
        y = z;
        z = (x / z + z) / 2;
    }
}
}