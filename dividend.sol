// SPDX-License-Identifier: MIT 
pragma solidity 0.8.9;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}


contract Dividend is  Ownable, ReentrancyGuard{
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    Counters.Counter DividendCount;
    mapping(uint256 => FinancialRecord) public idToDividend;
    mapping(address => bool) public isFinancialAdmin;
    mapping(uint256 => address[]) public idToListOfReceivers;
    mapping(uint256=> uint256) public idToAmountDistributed;
    mapping(uint256 => uint256[]) public standardToDividend;
    mapping(uint256 => mapping(address => bool)) dividendRecieved;
    mapping(uint256 => mapping(address => uint256)) recievedAmount;
    event FinancialEntry(uint256 id);
    event DividendDistrbuted(uint256 amount);

    constructor() {
       
        isFinancialAdmin[msg.sender] = true;
    }

struct FinancialRecord{
        uint256 entryId;
        uint256 standard;
        uint256 id;
        bool isProfitable;
        uint256 profit;
        uint256 loss;
        uint256 amountEarned;
        uint256 timeOfRecord;
        uint256 percentageDistributed;

    }



       function recordDividend(uint256 standard, uint256 id, uint256 totalAmount, uint256 profit,bool profitable, uint256 loss, uint256 perecent)
     external returns(uint256 _id){
        require(isFinancialAdmin[msg.sender]==true,"Access Denied");
        require(standard == 1155 || standard == 721, "Invalid Input");
        uint256 _entryId = DividendCount.current();
        idToDividend[_entryId].entryId = _entryId;
        idToDividend[_entryId].standard = standard;
        idToDividend[_entryId].id = id;
        idToDividend[_entryId].isProfitable = profitable;
        idToDividend[_entryId].timeOfRecord = block.timestamp;
        idToDividend[_entryId].profit = profit;
        idToDividend[_entryId].loss = loss;
        idToDividend[_entryId].amountEarned = totalAmount;
        idToDividend[_entryId].percentageDistributed = perecent;
        standardToDividend[standard].push(_entryId);
        DividendCount.increment();
        emit FinancialEntry(_entryId);
        return(_entryId);

    }

    function distribute(uint256 dividendNumber, address[] memory users, uint256[] memory amounts) external payable {
        require(isFinancialAdmin[msg.sender]==true,"Access Denied");
        require(dividendNumber < DividendCount.current(),"Entry not done"); 
        require(users.length == amounts.length,"Length Mismatch");
        uint256 totalAmount;
        for(uint256 i=0; i< users.length; i++){
            totalAmount = totalAmount + amounts[i];
        }
        require(msg.value == totalAmount,"Amount Mismatched");
        for(uint256 i=0; i< users.length; i++){
            payable(users[i]).transfer(amounts[i]);
            dividendRecieved[dividendNumber][users[i]]= true;
            recievedAmount[dividendNumber][users[i]] = amounts[i];
            idToListOfReceivers[dividendNumber].push(users[i]);
        }
        idToAmountDistributed[dividendNumber] = idToAmountDistributed[dividendNumber]+ totalAmount;
        emit DividendDistrbuted(totalAmount);
    }

    function getStandardToFinancialEntry(uint256 standard) external view returns(FinancialRecord[] memory){
       uint256 count = 0;
        uint256 total = DividendCount.current();
           for(uint256 j=0; j<total;j++){
               if(idToDividend[j].standard == standard)
               count++;
           }
        

    FinancialRecord[] memory info = new FinancialRecord[](count);
    uint256 number=0;
           for(uint256 j=0; j<total;j++){
              if(idToDividend[j].standard == standard){
        info[number].entryId = idToDividend[j].entryId;
        info[number].standard= idToDividend[j].standard;
        info[number].id = idToDividend[j].id ;
        info[number].isProfitable = idToDividend[j].isProfitable;
        info[number].timeOfRecord = idToDividend[j].timeOfRecord ;
        info[number].profit =idToDividend[j].profit ;
        info[number].loss = idToDividend[j].loss;
        info[number].amountEarned = idToDividend[j].amountEarned;
        info[number].percentageDistributed = idToDividend[j].percentageDistributed;
                  number++;
              }  
           }
    return(info);  
    }

    function getIdToFinancialEntry(uint256 id) external view returns(FinancialRecord[] memory){
       uint256 count = 0;
        uint256 total = DividendCount.current();
           for(uint256 j=0; j<total;j++){
               if(idToDividend[j].standard == 1155 && idToDividend[j].id == id)
               count++;
           }
        

    FinancialRecord[] memory info = new FinancialRecord[](count);
    uint256 number=0;
           for(uint256 j=0; j<total;j++){
              if(idToDividend[j].standard == 1155 && idToDividend[j].id == id){
        info[number].entryId = idToDividend[j].entryId;
        info[number].standard= idToDividend[j].standard;
        info[number].id = idToDividend[j].id ;
        info[number].isProfitable = idToDividend[j].isProfitable;
        info[number].timeOfRecord = idToDividend[j].timeOfRecord ;
        info[number].profit =idToDividend[j].profit ;
        info[number].loss = idToDividend[j].loss;
        info[number].amountEarned = idToDividend[j].amountEarned;
        info[number].percentageDistributed = idToDividend[j].percentageDistributed;
                  number++;
              }  
           }
    return(info);  
    }

    function editFinancialAdmin(address[] memory users, bool isFin) external onlyOwner{
      for(uint256 i=0; i< users.length;i++){
          isFinancialAdmin[users[i]] = isFin;
      }
    }


  function withdrawFunds(address wallet) external onlyOwner{
        uint256 balanceOfContract = address(this).balance;
        payable(wallet).transfer(balanceOfContract);
    }


}
