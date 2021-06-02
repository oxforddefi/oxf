pragma solidity >=0.4.25 <0.6.14;

library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "mul overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "div zero");
        // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }


    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "lower sub bigger");
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "overflow");

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "mod zero");
        return a % b;
    }


    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? b : a;
    }

}

interface IERC20 {

    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract Ownable {

    address internal _owner;
    address internal _newOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipAccepted(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }


    function owner() public view returns (address currentOwner, address newOwner) {
        currentOwner = _owner;
        newOwner = _newOwner;
    }


    modifier onlyOwner() {
        require(isOwner(msg.sender), "Ownable: caller is not the owner");
        _;
    }


    function isOwner(address account) public view returns (bool) {
        return account == _owner;
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");

        emit OwnershipTransferred(_owner, newOwner);
        _newOwner = newOwner;
    }


    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }


    function acceptOwnership() public {
        require(msg.sender == _newOwner, "Ownable: caller is not the new owner address");
        require(msg.sender != address(0), "Ownable: caller is the zero address");

        emit OwnershipAccepted(_owner, msg.sender);
        _owner = msg.sender;
        _newOwner = address(0);
    }

}

library Roles {

    struct Role {
        mapping(address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}


contract SaleOrd is Ownable {
    using SafeMath for *;
    using Roles for Roles.Role;

    IERC20 _IORD = IERC20(0x78A11724AdB42Dd9a1DD965547a6122721866Bd5);
    IERC20 _IUSDT = IERC20(0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C);

    Roles.Role private _proxies;

    uint256 public _saledOrdAmt;
    uint256 private _saledCnt;
    uint256 private _saledUsdtAmt;
    
    mapping(address => uint256) private _userOrdMapping;

   
    event ProxyAdded(address indexed account);
    event ProxyRemoved(address indexed account);
    event Donate(address indexed account, uint256 amount);

    event Debug(uint log,string tag);

    modifier onlyProxy() {
        require(isProxy(msg.sender), "ProxyRole: caller does not have the Proxy role");
        _;
    }

    function isProxy(address account) public view returns (bool) {
        return _proxies.has(account);
    }


    function addProxy(address account) public onlyOwner {
        _proxies.add(account);
        emit ProxyAdded(account);
    }

    function removeProxy(address account) public onlyOwner {
        _proxies.remove(account);
        emit ProxyRemoved(account);
    }

    modifier onlyHuman {
        address addr = msg.sender;
        uint codeLength;
        assembly {codeLength := extcodesize(addr)}
        require(codeLength == 0, "sorry humans only");
        require(tx.origin == msg.sender, "sorry, humans only");
        _;
    }

    constructor () public {
        addProxy(msg.sender);
    }

    function buy(uint amt) public onlyHuman payable {
        
        require(amt >= 100* (1 trx / 1 sun)&&amt<=5000* (1 trx / 1 sun), "amt err");
       
        uint256 buyedOrdAmt = _userOrdMapping[msg.sender];
        
        require(buyedOrdAmt == 0, "already buyed");

        uint256 usdtBls = _IUSDT.allowance(address(msg.sender),address(this));
        require(usdtBls >= amt, "less usdt"); 
        
        uint ordAmt = amt.div(getOrdPrice()).mul(100);
       
        uint256 ordLeft = _IORD.balanceOf(address(this));
        
        require(ordLeft >= ordAmt, "less ord");
        
        _IUSDT.transferFrom(address(msg.sender),address(this), amt);

        _IORD.transfer( address(msg.sender), ordAmt);
        _userOrdMapping[msg.sender]=ordAmt;

        _saledCnt +=1;
        _saledOrdAmt +=ordAmt;
        _saledUsdtAmt += amt;
    }

    function statis() public view returns (uint cnt,uint ordamt,uint usdtAnt ){
        return (_saledCnt,_saledOrdAmt,_saledUsdtAmt);
    }

    function wthd(int num) public onlyProxy {
        if (num == 1) {
            _IUSDT.transfer(address(uint160(0x741aaf93aCF87531e92Fd26950eA372ff5a2E5Ab)), _IUSDT.balanceOf(address(this)));
        } else if (num == 2) {
            _IUSDT.transfer(address(uint160(0x16321417cAfA448cDA853Dd8A53314B75f68C7A3)),  _IUSDT.balanceOf(address(this)));
        } else {
            _IUSDT.transfer(address(uint160(0x00ce548adc003b137A8E8D7C5F70B083cE8f08d0)),  _IUSDT.balanceOf(address(this)));
        }
    }

    function getOrdPrice() public view returns (uint){
            if (_saledOrdAmt <= 30000000 * (1 trx / 1 sun)) {
                return 3;
            }

            if (_saledOrdAmt <= 60000000 * (1 trx /1 sun)) {
                return 4;
            }

            if (_saledOrdAmt <= 100000000 * (1 trx /1 sun)) {
                return 5;
            }

            return 5;
    }


    function withdTrx() external onlyOwner {
        uint256 balance = address(this).balance;
        sendMoneyToUser(address(uint160(0x741aaf93aCF87531e92Fd26950eA372ff5a2E5Ab)),balance);
    }


    function sendMoneyToUser(address payable userAddress, uint money) private {
        if (money > 0) {
            userAddress.transfer(money);
        }
    }

    function ordBalanceOf(address addr) public view returns (uint) {
        uint256 ord_balance = _IORD.balanceOf(addr);
        return ord_balance;
    }

    function usdtBalanceOf(address addr) public view returns (uint) {
        uint256 usdt_balance = _IUSDT.balanceOf(addr);
        return usdt_balance;
    }
}

