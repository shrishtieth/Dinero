// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISecondaryMarketFees {

  struct Fee {
    address recipient;
    uint256 value;
  }
  
  function getFeeRecipients(uint256 tokenId) external view returns(address[] memory);

  function getFeeBps(uint256 tokenId) external view returns(uint256[] memory);


}

contract Ownership {

  address public owner;
  address[] private deputyOwners;

  mapping(address => bool) public isDeputyOwner;


  event OwnershipUpdated(address oldOwner, address newOwner);
  event DeputyOwnerUpdated(address _do, bool _isAdded);

  constructor() {
    owner = msg.sender;
    deputyOwners = [msg.sender];
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner is allowed");
    _;
  }

  modifier onlyAdmin() {
    require(isAdmin(msg.sender), "Only owner or deputy owner is allowed");
    _;
  }

  function isAdmin(address user) internal view returns(bool) {
    return user == owner || isDeputyOwner[user];
  }


  /**
   * @dev Transfer the ownership to some other address.
   * new owner can not be a zero address.
   * Only owner can call this function
   * @param _newOwner Address to which ownership is being transferred
   */
  function updateOwner(address _newOwner)
    public
    onlyOwner
  {
    require(_newOwner != address(0), "Zero address not allowed");
    owner = _newOwner;
    emit OwnershipUpdated(msg.sender, owner);
  }

  /**
    * @dev Add new deputy owner.
    * Only Owner can call this function
    * New Deputy should not be zero address
    * New Deputy should not be be already exisitng
    * emit DeputyOwnerUdpatd event
    * @param _newDO Address of new deputy owner
   */
  function addDeputyOwner(address _newDO)
    public
    onlyOwner
  {
    require(!isDeputyOwner[_newDO], "Deputy Owner already exists");
    require(_newDO != address(0), "Zero address not allowed");
    deputyOwners.push(_newDO);
    isDeputyOwner[_newDO] = true;
    emit DeputyOwnerUpdated(_newDO, true);
  }

  /**
    * @dev Remove an existing deputy owner.
    * Only Owner can call this function
    * Given address should be a deputy owner
    * emit DeputyOwnerUdpatd event
    * @param _existingDO Address of existing deputy owner
   */
  function removeDeputyOwner(address _existingDO)
    public
    onlyOwner
  {
    require(isDeputyOwner[_existingDO], "Deputy Owner does not exits");
    uint existingId;
    for(uint i=0; i<deputyOwners.length; i++) {
      if(deputyOwners[i] == _existingDO) existingId=i;
    }

    // swap this with last element
    deputyOwners[existingId] = deputyOwners[deputyOwners.length-1];
    deputyOwners.pop();
    isDeputyOwner[_existingDO] = false;
    emit DeputyOwnerUpdated(_existingDO, false);
  }

  /**
   * @dev Renounce the ownership.
   * This will leave the contract without any owner.
   * Only owner can call this function
   * @param _validationCode A code to prevent aaccidental calling of this function
   */
  function renounceOwnership(uint _validationCode)
    public
    onlyOwner
  {
    require(_validationCode == 123456789, "Invalid code");
    owner = address(0);
    emit OwnershipUpdated(msg.sender, owner);
  }
  
  /**
   * @dev Get deputy owner at given index
   * @param index Index at which deputy owner is fetched from list of deputy owners
   * @return returns deputy owner at provided index
   */
  function getDeputyOwners(uint index) public view returns (address) {
    return deputyOwners[index];
  }

}



contract SecondaryMarketFee is ISecondaryMarketFees, Ownership {

  address public ownerContract;
  uint256 public decimals;

  mapping (uint256 => Fee[]) public fees;

  /*
    * bytes4(keccak256('getFeeBps(uint256)')) == 0x0ebd4c7f
    * bytes4(keccak256('getFeeRecipients(uint256)')) == 0xb9c4d9fb
    *
    * => 0x0ebd4c7f ^ 0xb9c4d9fb == 0xb7799584
    */
  bytes4 public constant _INTERFACE_ID_FEES = 0xb7799584;

  event SecondarySaleFees(uint256 tokenId, Fee[] _fees);

  constructor() {
    decimals = 3; // this makes min "fee" to be 0.001% for any recipient
  }


  /**
   * @dev Get fee recipients when asset is sold in secondary market
   * @param tokenId Id of NFT for which fee recipients are to be fetched
   * @return array of addresses that'll recieve the commission when sold in secondary market
   */
  function getFeeRecipients(uint256 tokenId) public override view returns(address[] memory) {
    Fee[] memory _fees = fees[tokenId];
    address[] memory _recipients = new address[](_fees.length);
    for(uint256 i=0;  i<_fees.length; i++) {
      _recipients[i] = _fees[i].recipient;
    }
    return _recipients;
  }


  /**
   * @dev Get fee values when asset is sold in secondary market
   * @param tokenId Id of NFT for which fee values are to be fetched
   * @return array of fees percentages that'll the recipients wil get when sold in secondary market
   */
  function getFeeBps(uint256 tokenId) public override view returns(uint256[] memory) {
    Fee[] memory _fees = fees[tokenId];
    uint256[] memory _values = new uint256[](_fees.length);
    for(uint256 i=0;  i<_fees.length; i++) {
      _values[i] = _fees[i].value;
    }
    return _values;
  }

  /**
   * @dev Add fees (address and percentage) for a tokenId
   * @param tokenId Id of NFT for which fee values are to be added
   * @param _fees Fee struct (with address and fee percentage) for given `tokenId`
   * @dev array of fees percentages that'll the recipients wil get when sold in secondary market
   */
  function addFees(uint256 tokenId, Fee[] memory _fees) internal {
    uint256 totalPercentage = 0;
    for (uint256 i = 0; i < _fees.length; i++) {
      require(_fees[i].recipient != address(0x0), "Recipient should be present");
      require(_fees[i].value != 0, "Fee value should not be zero");
      totalPercentage += _fees[i].value;
      fees[tokenId].push(_fees[i]);
    }
    require(totalPercentage < 100 * 10 ** decimals, "percentage should be max 100");
    emit SecondarySaleFees(tokenId, _fees);
  }

  function removeFees(uint256 tokenId) internal {
    delete(fees[tokenId]);
  }


}


contract MultiShareHolders is SecondaryMarketFee {
    address[] internal shareHolders;
    mapping(address => uint256) public shareHoldings;

    constructor(
        address[] memory _shareHolders,
        uint256[] memory _percentageShares
    ) {
        require(
            _shareHolders.length == _percentageShares.length,
            "Array length mismatch"
        );
        updateShareholding(_shareHolders, _percentageShares);
    }

    function getShareHolders() external view returns (address[] memory) {
        return shareHolders;
    }

    function updateShareholding(
        address[] memory _shareHolders,
        uint256[] memory _percentageShares
    ) public onlyAdmin {
        require(
            _shareHolders.length == _percentageShares.length,
            "Array length mismatch"
        );
        uint256 totalShares;

        for (uint256 i = 0; i < _shareHolders.length; i++) {
            // if shareholder not exist, add to the list
            if (shareHoldings[_shareHolders[i]] == 0) {
                shareHolders.push(_shareHolders[i]);
            }
            shareHoldings[_shareHolders[i]] = _percentageShares[i];
            // if shareholding is reduced to zero, remove from the list
            if (shareHoldings[_shareHolders[i]] == 0) {
                _removeShareHolder(i);
            }
        }

        for (uint256 i = 0; i < shareHolders.length; i++) {
            totalShares += shareHoldings[shareHolders[i]];
        }

       // require(totalShares == 100, "Total shareholdings not 100");
    }

    function _removeShareHolder(uint256 _deleteIndex) private {
        uint256 lastIndex = shareHolders.length - 1;
        if (_deleteIndex != lastIndex) {
            shareHolders[_deleteIndex] = shareHolders[lastIndex];
        }
        shareHolders.pop();
    }

    function getRoyaltiesForShareHolders()
        internal
        view
        returns (Fee[] memory)
    {
        Fee[] memory royalties = new Fee[](shareHolders.length);
        for (uint256 i = 0; i < shareHolders.length; i++) {
            Fee memory royalty;
            address shareHolder = shareHolders[i];
            royalty.recipient = shareHolder;
            royalty.value = shareHoldings[shareHolder];
            royalties[i] = royalty;
        }
        return royalties;
    }

    function updateRoyaltyForToken(uint256 tokenId) external onlyAdmin {
        Fee[] memory royalties = getRoyaltiesForShareHolders();
        super.removeFees(tokenId);
        super.addFees(tokenId, royalties);
    }

    function updateRoyaltyForTokenBatch(uint256[] memory tokenIds) external onlyAdmin {
        Fee[] memory royalties = getRoyaltiesForShareHolders();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            super.removeFees(tokenIds[i]);
            super.addFees(tokenIds[i], royalties);
        }
    }
}

interface ERC165 {

  /**
   * @notice Query if a contract implements an interface
   * @param _interfaceId The interface identifier, as specified in ERC-165
   * @dev Interface identification is specified in ERC-165.
   */
  function supportsInterface(bytes4 _interfaceId)
    external
    view
    returns (bool);
}


/**
 * @title ERC721 Non-Fungible Token Standard basic interface
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
abstract contract ERC721Basic is ERC165 {
  event Transfer(
    address indexed _from,
    address indexed _to,
    uint256 indexed _tokenId
  );
  event Approval(
    address indexed _owner,
    address indexed _approved,
    uint256 indexed _tokenId
  );
  event ApprovalForAll(
    address indexed _owner,
    address indexed _operator,
    bool _approved
  );

  function balanceOf(address _owner) public virtual view returns (uint256 _balance);
  function ownerOf(uint256 _tokenId) public virtual view returns (address _owner);
  function exists(uint256 _tokenId) public virtual view returns (bool _exists);

  function approve(address _to, uint256 _tokenId) virtual public;
  function getApproved(uint256 _tokenId)
    public virtual view returns (address _operator);

  function setApprovalForAll(address _operator, bool _approved) virtual public;
  function isApprovedForAll(address _owner, address _operator)
    public virtual view returns (bool);

  function transferFrom(address _from, address _to, uint256 _tokenId) virtual public;
  function safeTransferFrom(address _from, address _to, uint256 _tokenId)
    virtual public;

  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes memory _data
  )
    virtual public;
}

abstract  contract ERC721Enumerable is ERC721Basic {
  function totalSupply() public virtual view returns (uint256);
  function tokenOfOwnerByIndex(
    address _owner,
    uint256 _index
  )
    public
    virtual
    view
    returns (uint256 _tokenId);

  function tokenByIndex(uint256 _index) public virtual view returns (uint256);
}

abstract contract ERC721Metadata is ERC721Basic {
  function name() external virtual view returns (string memory _name);
  function symbol() external virtual view returns (string memory _symbol);
  function tokenURI(uint256 _tokenId) public virtual view returns (string memory);
}


/**
 * @title ERC-721 Non-Fungible Token Standard, full implementation interface
 * @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
abstract contract ERC721 is ERC721Basic, ERC721Enumerable, ERC721Metadata {

}

abstract contract IERC20 {
  function transfer(address to, uint tokens) public virtual returns (bool success);
  function balanceOf(address _sender) public virtual view returns (uint _bal);
  function allowance(address tokenOwner, address spender) public virtual view returns (uint remaining);
  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  function transferFrom(address from, address to, uint tokens) public virtual returns (bool success);
}


/**
 * @title Base ERC721 token
 * This contract implements basic ERC721 token functionality with bulk functionalities
 */



abstract contract ERC721Receiver {
  /**
   * @dev Magic value to be returned upon successful reception of an NFT
   *  Equals to `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`,
   *  which can be also obtained as `ERC721Receiver(0).onERC721Received.selector`
   */
  bytes4 internal constant ERC721_RECEIVED = 0xf0b9e5ba;

  /**
   * @notice Handle the receipt of an NFT
   * @dev The ERC721 smart contract calls this function on the recipient
   * after a `safetransfer`. This function MAY throw to revert and reject the
   * transfer. This function MUST use 50,000 gas or less. Return of other
   * than the magic value MUST result in the transaction being reverted.
   * Note: the contract address is always the message sender.
   * @param _from The sending address
   * @param _tokenId The NFT identifier which is being transfered
   * @param _data Additional data with no specified format
   * @return `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`
   */
  function onERC721Received(
    address _from,
    uint256 _tokenId,
    bytes memory _data
  )
    public
    virtual
    returns(bytes4);
}

contract Freezable is Ownership {
    
    bool public emergencyFreeze = false;

    event EmerygencyFreezed(bool emergencyFreezeStatus);

    modifier noEmergencyFreeze() { 
        require(!emergencyFreeze, "Contract is freezed");
        _; 
    }

    /**
     * @dev Admin can freeze/unfreeze the contract
     * Reverts if sender is not the owner of contract
     * @param _freeze Boolean valaue; true is used to freeze and false for unfreeze
     */ 
    function emergencyFreezeAllAccounts (bool _freeze) public onlyOwner returns(bool) {
        emergencyFreeze = _freeze;
        emit EmerygencyFreezed(_freeze);
        return true;
    }

}

library Address {
  

	/**
	* @dev Returns true if `account` is a contract.
	*
	* [IMPORTANT]
	* ====
	* It is unsafe to assume that an address for which this function returns
	* false is an externally-owned account (EOA) and not a contract.
	*
	* Among others, `isContract` will return false for the following
	* types of addresses:
	*
	*  - an externally-owned account
	*  - a contract in construction
	*  - an address where a contract will be created
	*  - an address where a contract lived, but was destroyed
	* ====
	*/
	function isContract(address account) internal view returns (bool) {
	// This method relies on extcodesize, which returns 0 for contracts in
	// construction, since the code is only stored at the end of the
	// constructor execution.

	uint256 size;
	// solhint-disable-next-line no-inline-assembly
	assembly { size := extcodesize(account) }
	return size > 0;
	}

	function functionCall(address target, bytes memory data) internal returns (bytes memory) {
		return functionCall(target, data, "Address: low-level call failed");
	}

	/**
		* @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
		* `errorMessage` as a fallback revert reason when `target` reverts.
		*
		* _Available since v3.1._
		*/
	function functionCall(
		address target,
		bytes memory data,
		string memory errorMessage
	) internal returns (bytes memory) {
		return functionCallWithValue(target, data, 0, errorMessage);
	}

	/**
		* @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
		* but also transferring `value` wei to `target`.
		*
		* Requirements:
		*
		* - the calling contract must have an ETH balance of at least `value`.
		* - the called Solidity function must be `payable`.
		*
		* _Available since v3.1._
		*/
	function functionCallWithValue(
		address target,
		bytes memory data,
		uint256 value
	) internal returns (bytes memory) {
		return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
	}


	/**
		* @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
		* with `errorMessage` as a fallback revert reason when `target` reverts.
		*
		* _Available since v3.1._
		*/
	function functionCallWithValue(
		address target,
		bytes memory data,
		uint256 value,
		string memory errorMessage
	) internal returns (bytes memory) {
		require(address(this).balance >= value, "Address: insufficient balance for call");
		require(isContract(target), "Address: call to non-contract");

		(bool success, bytes memory returndata) = target.call{value: value}(data);
		return verifyCallResult(success, returndata, errorMessage);
	}


	/**
		* @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
		* revert reason using the provided one.
		*
		* _Available since v4.3._
		*/
	function verifyCallResult(
		bool success,
		bytes memory returndata,
		string memory errorMessage
	) internal pure returns (bytes memory) {
		if (success) {
			return returndata;
		} else {
			// Look for revert reason and bubble it up if present
			if (returndata.length > 0) {
				// The easiest way to bubble the revert reason is using memory via assembly

				assembly {
					let returndata_size := mload(returndata)
					revert(add(32, returndata), returndata_size)
				}
			} else {
				revert(errorMessage);
			}
		}
	}
}


/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */


contract SupportsInterfaceWithLookup is ERC165 {
  bytes4 public constant InterfaceId_ERC165 = 0x01ffc9a7;
  /**
   * 0x01ffc9a7 ===
   *   bytes4(keccak256('supportsInterface(bytes4)'))
   */

  /**
   * @dev a mapping of interface id to whether or not it's supported
   */
  mapping(bytes4 => bool) internal supportedInterfaces;

  /**
   * @dev A contract implementing SupportsInterfaceWithLookup
   * implement ERC165 itself
   */
  constructor()
  {
    _registerInterface(InterfaceId_ERC165);
  }

  /**
   * @dev implement supportsInterface(bytes4) using a lookup table
   */
  function supportsInterface(bytes4 _interfaceId)
    external
    override
    view
    returns (bool)
  {
    return supportedInterfaces[_interfaceId];
  }

  /**
   * @dev private method for registering an interface
   */
  function _registerInterface(bytes4 _interfaceId)
    internal
  {
    require(_interfaceId != 0xffffffff);
    supportedInterfaces[_interfaceId] = true;
  }
}

library Strings {
   
    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}



/**
 * @title Full ERC721 Token
 * @author Prashant Prabhakar Singh [prashantprabhakar123@gmail.com]
 * This implementation includes all the required and some optional functionality of the ERC721 standard
 * Moreover, it includes approve all functionality using operator terminology
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
 contract ERC721BasicToken is SupportsInterfaceWithLookup, ERC721Basic, Freezable {

  bytes4 private constant InterfaceId_ERC721 = 0x80ac58cd;
  /*
   * 0x80ac58cd ===
   *   bytes4(keccak256('balanceOf(address)')) ^
   *   bytes4(keccak256('ownerOf(uint256)')) ^
   *   bytes4(keccak256('approve(address,uint256)')) ^
   *   bytes4(keccak256('getApproved(uint256)')) ^
   *   bytes4(keccak256('setApprovalForAll(address,bool)')) ^
   *   bytes4(keccak256('isApprovedForAll(address,address)')) ^
   *   bytes4(keccak256('transferFrom(address,address,uint256)')) ^
   *   bytes4(keccak256('safeTransferFrom(address,address,uint256)')) ^
   *   bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
   */

  bytes4 private constant InterfaceId_ERC721Exists = 0x4f558e79;
  /*
   * 0x4f558e79 ===
   *   bytes4(keccak256('exists(uint256)'))
   */

  using Address for address;

  // Equals to `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`
  // which can be also obtained as `ERC721Receiver(0).onERC721Received.selector`
  bytes4 private constant ERC721_RECEIVED = 0xf0b9e5ba;

  // Mapping from token ID to owner
  mapping (uint256 => address) internal tokenOwner;

  // Mapping from token ID to approved address
  mapping (uint256 => address) internal tokenApprovals;

  // Mapping from owner to number of owned token
  mapping (address => uint256) internal ownedTokensCount;

  // Mapping from owner to operator approvals
  mapping (address => mapping (address => bool)) internal operatorApprovals;

  /**
   * @dev Guarantees msg.sender is owner of the given token
   * @param _tokenId uint256 ID of the token to validate its ownership belongs to msg.sender
   */
  modifier onlyOwnerOf(uint256 _tokenId) {
    require(ownerOf(_tokenId) == msg.sender, "Only asset owner is allowed");
    _;
  }

  /**
   * @dev Checks msg.sender can transfer a token, by being owner, approved, or operator
   * @param _tokenId uint256 ID of the token to validate
   */
  modifier canTransfer(uint256 _tokenId) {
    require(isApprovedOrOwner(msg.sender, _tokenId), "Can not transfer");
    _;
  }

  constructor()
  {
    // register the supported interfaces to conform to ERC721 via ERC165
    _registerInterface(InterfaceId_ERC721);
    _registerInterface(InterfaceId_ERC721Exists);
  }

  /**
   * @dev Gets the balance of the specified address
   * @param _owner address to query the balance of
   * @return uint256 representing the amount owned by the passed address
   */
  function balanceOf(address _owner) public override view returns (uint256) {
    require(_owner != address(0), "Zero address not allowed");
    return ownedTokensCount[_owner];
  }

  /**
   * @dev Gets the owner of the specified token ID
   * @param _tokenId uint256 ID of the token to query the owner of
   * @return owner address currently marked as the owner of the given token ID
   */
  function ownerOf(uint256 _tokenId) public override view returns (address) {
    address owner = tokenOwner[_tokenId];
    require(owner != address(0), "Zero address not allowed");
    return owner;
  }

  /**
   * @dev Returns whether the specified token exists
   * @param _tokenId uint256 ID of the token to query the existence of
   * @return whether the token exists
   */
  function exists(uint256 _tokenId) public override view returns (bool) {
    address owner = tokenOwner[_tokenId];
    return owner != address(0);
  }

  /**
   * @dev Approves another address to transfer the given token ID
   * The zero address indicates there is no approved address.
   * There can only be one approved address per token at a given time.
   * Can only be called by the token owner or an approved operator.
   * @param _to address to be approved for the given token ID
   * @param _tokenId uint256 ID of the token to be approved
   */
  function approve(address _to, uint256 _tokenId) public override {
    address owner = ownerOf(_tokenId);
    require(_to != owner, "Can not approve to self");
    require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "Not allowed to update approvals");

    tokenApprovals[_tokenId] = _to;
    emit Approval(owner, _to, _tokenId);
  }

  /**
   * @dev Gets the approved address for a token ID, or zero if no address set
   * @param _tokenId uint256 ID of the token to query the approval of
   * @return address currently approved for the given token ID
   */
  function getApproved(uint256 _tokenId) public override view returns (address) {
    return tokenApprovals[_tokenId];
  }

  /**
   * @dev Sets or unsets the approval of a given operator
   * An operator is allowed to transfer all tokens of the sender on their behalf
   * @param _to operator address to set the approval
   * @param _approved representing the status of the approval to be set
   */
  function setApprovalForAll(address _to, bool _approved) public override {
    require(_to != msg.sender, "Can not approve to self");
    operatorApprovals[msg.sender][_to] = _approved;
    emit ApprovalForAll(msg.sender, _to, _approved);
  }

  /**
   * @dev Tells whether an operator is approved by a given owner
   * @param _owner owner address which you want to query the approval of
   * @param _operator operator address which you want to query the approval of
   * @return bool whether the given operator is approved by the given owner
   */
  function isApprovedForAll(
    address _owner,
    address _operator
  )
    public
    override
    view
    returns (bool)
  {
    return operatorApprovals[_owner][_operator];
  }

  /**
   * @dev Transfers the ownership of a given token ID to another address
   * Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * Requires the msg sender to be the owner, approved, or operator
   * @param _from current owner of the token
   * @param _to address to receive the ownership of the given token ID
   * @param _tokenId uint256 ID of the token to be transferred
  */
  function transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    public
    override virtual
    noEmergencyFreeze
    canTransfer(_tokenId)
  {
    require(_from != address(0), "Zero address not allowed");
    require(_to != address(0), "Zero address not allowed");

    clearApproval(_from, _tokenId);
    removeTokenFrom(_from, _tokenId);
    addTokenTo(_to, _tokenId);

    emit Transfer(_from, _to, _tokenId);
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   *
   * Requires the msg sender to be the owner, approved, or operator
   * @param _from current owner of the token
   * @param _to address to receive the ownership of the given token ID
   * @param _tokenId uint256 ID of the token to be transferred
  */
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    public
    override virtual
    noEmergencyFreeze
    canTransfer(_tokenId)
  
  {
    // solium-disable-next-line arg-overflow
    safeTransferFrom(_from, _to, _tokenId, "");
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   * Requires the msg sender to be the owner, approved, or operator
   * @param _from current owner of the token
   * @param _to address to receive the ownership of the given token ID
   * @param _tokenId uint256 ID of the token to be transferred
   * @param _data bytes data to send along with a safe transfer check
   */
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes memory _data
  )
    public
    override virtual
    noEmergencyFreeze
    canTransfer(_tokenId)
  {
    transferFrom(_from, _to, _tokenId);
    // solium-disable-next-line arg-overflow
    require(checkAndCallSafeTransfer(_from, _to, _tokenId, _data), "Safe Transfer failed");
  }

  /**
   * @dev Returns whether the given spender can transfer a given token ID
   * @param _spender address of the spender to query
   * @param _tokenId uint256 ID of the token to be transferred
   * @return bool whether the msg.sender is approved for the given token ID,
   *  is an operator of the owner, or is the owner of the token
   */
  function isApprovedOrOwner(
    address _spender,
    uint256 _tokenId
  )
    internal
    view
    returns (bool)
  {
    address owner = ownerOf(_tokenId);
    // Disable solium check because of
    // https://github.com/duaraghav8/Solium/issues/175
    // solium-disable-next-line operator-whitespace
    return (
      _spender == owner ||
      getApproved(_tokenId) == _spender ||
      isApprovedForAll(owner, _spender)
    );
  }

  /**
   * @dev Internal function to mint a new token
   * Reverts if the given token ID already exists
   * @param _to The address that will own the minted token
   * @param _tokenId uint256 ID of the token to be minted by the msg.sender
   */
  function _mint(address _to, uint256 _tokenId) internal virtual {
    require(_to != address(0), "Zero address not allowed");
    addTokenTo(_to, _tokenId);
    emit Transfer(address(0), _to, _tokenId);
  }

  /**
   * @dev Internal function to burn a specific token
   * Reverts if the token does not exist
   * @param _tokenId uint256 ID of the token being burned by the msg.sender
   */
  function _burn(address _owner, uint256 _tokenId) internal virtual {
    clearApproval(_owner, _tokenId);
    removeTokenFrom(_owner, _tokenId);
    emit Transfer(_owner, address(0), _tokenId);
  }

  /**
   * @dev Internal function to clear current approval of a given token ID
   * Reverts if the given address is not indeed the owner of the token
   * @param _owner owner of the token
   * @param _tokenId uint256 ID of the token to be transferred
   */
  function clearApproval(address _owner, uint256 _tokenId) internal {
    require(ownerOf(_tokenId) == _owner, "Asset does not belong to given owmer");
    if (tokenApprovals[_tokenId] != address(0)) {
      tokenApprovals[_tokenId] = address(0);
      emit Approval(_owner, address(0), _tokenId);
    }
  }

  /**
   * @dev Internal function to add a token ID to the list of a given address
   * @param _to address representing the new owner of the given token ID
   * @param _tokenId uint256 ID of the token to be added to the tokens list of the given address
   */
  function addTokenTo(address _to, uint256 _tokenId) internal virtual {
    require(tokenOwner[_tokenId] == address(0), "Asset already exists");
    tokenOwner[_tokenId] = _to;
    ownedTokensCount[_to] = ownedTokensCount[_to] + 1;
  }

  /**
   * @dev Internal function to remove a token ID from the list of a given address
   * @param _from address representing the previous owner of the given token ID
   * @param _tokenId uint256 ID of the token to be removed from the tokens list of the given address
   */
  function removeTokenFrom(address _from, uint256 _tokenId) internal virtual {
    require(ownerOf(_tokenId) == _from, "Asset does not belong to given owner");
    ownedTokensCount[_from] = ownedTokensCount[_from] - 1;
    tokenOwner[_tokenId] = address(0);
  }

  /**
   * @dev Internal function to invoke `onERC721Received` on a target address
   * The call is not executed if the target address is not a contract
   * @param _from address representing the previous owner of the given token ID
   * @param _to target address that will receive the tokens
   * @param _tokenId uint256 ID of the token to be transferred
   * @param _data bytes optional data to send along with the call
   * @return whether the call correctly returned the expected magic value
   */
  function checkAndCallSafeTransfer(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes memory _data
  )
    internal
    returns (bool)
  {
    if (!_to.isContract()) {
      return true;
    }
    bytes4 retval = ERC721Receiver(_to).onERC721Received(
      _from, _tokenId, _data);
    return (retval == ERC721_RECEIVED);
  }
}

contract ERC721Token is SupportsInterfaceWithLookup, ERC721BasicToken, ERC721 {

  bytes4 private constant InterfaceId_ERC721Enumerable = 0x780e9d63;
 

  bytes4 private constant InterfaceId_ERC721Metadata = 0x5b5e139f;
 

  // Token name
  string internal name_;

  // Token symbol
  string internal symbol_;

  // to store base URL
  string internal baseTokenURI;

  // Mapping from owner to list of owned token IDs
  mapping(address => uint256[]) internal ownedTokens;

  // Mapping from token ID to index of the owner tokens list
  mapping(uint256 => uint256) internal ownedTokensIndex;

  // Array with all token ids, used for enumeration
  uint256[] internal allTokens;

  // Mapping from token id to position in the allTokens array
  mapping(uint256 => uint256) internal allTokensIndex;

  mapping(uint256 => string) private _tokenURIs;
  
  /**
   * @dev Constructor function
   */
  constructor(string memory _name, string memory _symbol) {
    name_ = _name;
    symbol_ = _symbol;

    // register the supported interfaces to conform to ERC721 via ERC165
    _registerInterface(InterfaceId_ERC721Enumerable);
    _registerInterface(InterfaceId_ERC721Metadata);
  }

  /**
   * @dev Gets the token name
   * @return string representing the token name
   */
  function name() external override view returns (string memory) {
    return name_;
  }

  /**
   * @dev Gets the token symbol
   * @return string representing the token symbol
   */
  function symbol() external  override view returns (string memory) {
    return symbol_;
  }

  /**
   * @dev Returns an URI for a given token ID
   * Throws if the token ID does not exist. May return an empty string.
   * @param _tokenId uint256 ID of the token to query
   */
  function tokenURI(uint256 _tokenId) public override view returns (string memory) {
    require(exists(_tokenId), "Asset does not exist");
    return string(abi.encodePacked(baseTokenURI, _tokenURIs[_tokenId]));
  }

  /**
   * @dev Gets the token ID at a given index of the tokens list of the requested owner
   * @param _owner address owning the tokens list to be accessed
   * @param _index uint256 representing the index to be accessed of the requested tokens list
   * @return uint256 token ID at the given index of the tokens list owned by the requested address
   */
  function tokenOfOwnerByIndex(
    address _owner,
    uint256 _index
  )
    public
    override
    view
    returns (uint256)
  {
    require(_index < balanceOf(_owner), "Invalid index");
    return ownedTokens[_owner][_index];
  }

  /**
   * @dev Gets the total amount of tokens stored by the contract
   * @return uint256 representing the total amount of tokens
   */
  function totalSupply() public override view returns (uint256) {
    return allTokens.length;
  }

  /**
   * @dev Gets the token ID at a given index of all the tokens in this contract
   * Reverts if the index is greater or equal to the total number of tokens
   * @param _index uint256 representing the index to be accessed of the tokens list
   * @return uint256 token ID at the given index of the tokens list
   */
  function tokenByIndex(uint256 _index) public  override view returns (uint256) {
    require(_index < totalSupply(), "Invalid index");
    return allTokens[_index];
  }

  // /**
  //  * @dev Internal function to set the token URI for a given token
  //  * Reverts if the token ID does not exist
  //  * @param _tokenId uint256 ID of the token to set its URI
  //  * @param _uri string URI to assign
  //  */
  function _setTokenURI(uint256 _tokenId, string memory _uri) internal {
    require(exists(_tokenId), "ERC721: Token does not exist");
    _tokenURIs[_tokenId] = _uri;
  }

  function _clearTokenURI(uint256 tokenId) internal {
    if (bytes(_tokenURIs[tokenId]).length != 0) {
      delete _tokenURIs[tokenId];
    }
  }

  /**
   * @dev Internal function to add a token ID to the list of a given address
   * @param _to address representing the new owner of the given token ID
   * @param _tokenId uint256 ID of the token to be added to the tokens list of the given address
   */
  function addTokenTo(address _to, uint256 _tokenId) internal override {
    super.addTokenTo(_to, _tokenId);
    uint256 length = ownedTokens[_to].length;
    ownedTokens[_to].push(_tokenId);
    ownedTokensIndex[_tokenId] = length;
  }

  /**
   * @dev Internal function to remove a token ID from the list of a given address
   * @param _from address representing the previous owner of the given token ID
   * @param _tokenId uint256 ID of the token to be removed from the tokens list of the given address
   */
   function removeTokenFrom(address _from, uint256 _tokenId) internal override {
     super.removeTokenFrom(_from, _tokenId);

     uint256 tokenIndex = ownedTokensIndex[_tokenId];
     uint256 lastTokenIndex = ownedTokens[_from].length -1;
     uint256 lastToken = ownedTokens[_from][lastTokenIndex];

     ownedTokens[_from][tokenIndex] = lastToken;
     ownedTokens[_from][lastTokenIndex] = 0;
     // Note that this will handle single-element arrays. In that case, both tokenIndex and lastTokenIndex are going to
     // be zero. Then we can make sure that we will remove _tokenId from the ownedTokens list since we are first swapping
     // the lastToken to the first position, and then dropping the element placed in the last position of the list

     ownedTokens[_from].pop();
    
     ownedTokensIndex[_tokenId] = 0;
     ownedTokensIndex[lastToken] = tokenIndex;
   }

  /**
   * @dev Internal function to mint a new token
   * Reverts if the given token ID already exists
   * @param _to address the beneficiary that will own the minted token
   * @param _tokenId uint256 ID of the token to be minted by the msg.sender
   */
  function _mint(address _to, uint256 _tokenId) internal  override {
    super._mint(_to, _tokenId);

    allTokensIndex[_tokenId] = allTokens.length;
    allTokens.push(_tokenId);
  }

  /**
   * @dev Internal function to burn a specific token
   * Reverts if the token does not exist
   * @param _owner owner of the token to burn
   * @param _tokenId uint256 ID of the token being burned by the msg.sender
   */
  function _burn(address _owner, uint256 _tokenId) internal override {
    super._burn(_owner, _tokenId);

    uint256 tokenIndex = allTokensIndex[_tokenId];
    uint256 lastTokenIndex = allTokens.length - 1;
    uint256 lastToken = allTokens[lastTokenIndex];

    allTokens[tokenIndex] = lastToken;
    allTokensIndex[lastToken] = tokenIndex;

    delete allTokensIndex[_tokenId];
    allTokens.pop();
  }
}
contract BaseERC721 is ERC721Token {

  constructor(string memory name, string memory symbol, string memory _baseTokenURI)  ERC721Token(name, symbol){
    baseTokenURI = _baseTokenURI;
  }

  /**
   * @dev Updates the base URL of token
   * Reverts if the sender is not owner
   * @param _newURI New base URL
   */
  function updateBaseTokenURI(string memory _newURI)
    public
    onlyOwner
  {
    baseTokenURI = _newURI;
  }

  /**
   * @dev Mints new token on blockchain
   * Reverts if the sender is not operator with level 1
   * @param _id Id of NFT to be minted
   * @dev URI is not provided because URI will be deducted based on baseURL
   */
  function _mint(address _to, uint256 _id,  string memory _uri)
    internal
    returns (bool)
  {
    super._mint(_to, _id);
    _setTokenURI(_id, _uri);
    return true;
  }

  /**
   * @dev Transfer tokens (similar to ERC-20 transfer)
   * Reverts if the sender is not owner of the NFT or approved
   * @param _to address to which token is transferred
   * @param _tokenId Id of NFT being transferred
   */
  function transfer(address _to, uint256 _tokenId)
    public virtual
    noEmergencyFreeze
    returns (bool)
  {
    safeTransferFrom(msg.sender, _to, _tokenId);
    return true;
  }

  /**
   * @dev Burn an existing NFT
   * @param _id Id of NFT to be burned
   */
  function burn(address user, uint _id)
    internal
    returns (bool)
  {
    super._burn(user, _id);
    _clearTokenURI(_id);
    return true;
  }

  //////////////////////////////////////////
  // PUBLICLY ACCESSIBLE METHODS (CONSTANT)
  //////////////////////////////////////////

}



/**
 * Modified CustomNFT contract. Option to add max supply is provided.
 */



contract CustomNFTCollection is
    BaseERC721,
    SecondaryMarketFee,
    MultiShareHolders
{
    uint256 public maxSupply;
    address[] public ownerList;
    uint256[] public tokenIds;
    mapping(uint256 => bool) public tokenIdAdded;
    mapping(address => bool) public addedToOwnerList;
    struct HolderInfo{
        uint256 id;
        address user;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address[] memory _shareHolders,
        uint256[] memory _percentageShares,
        uint256 _maxSupply
    )
        BaseERC721(_name, _symbol, _baseURI)
        MultiShareHolders(_shareHolders, _percentageShares)
    {
        _registerInterface(_INTERFACE_ID_FEES);
        maxSupply = _maxSupply;
    }

    function verifyMaxSupply() private view {
        if (maxSupply > 0)
            require(totalSupply() <= maxSupply, "Max supply reached");
    }

   
    function mint(
        uint256 tokenId,
        address to,
        Fee[] memory _fees,
        string memory uri
    ) external onlyAdmin noEmergencyFreeze returns (bool) {
        super._mint(to, tokenId, uri);
        super.addFees(tokenId, _fees);
        if(tokenIdAdded[tokenId]==false){
          tokenIds.push(tokenId);
          tokenIdAdded[tokenId]= true;
        }
        verifyMaxSupply();
        if(addedToOwnerList[to]==false){
            ownerList.push(to);
            addedToOwnerList[to] = true;
        }
        return true;
    }


    function bulkMint(
        uint256[] memory _tokenIds,
        address to,
        Fee[] memory _fees,
        string[] memory uris
    ) external onlyAdmin noEmergencyFreeze returns (bool) {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            super._mint(to, _tokenIds[i], uris[i]);
            super.addFees(_tokenIds[i], _fees);
            if(tokenIdAdded[_tokenIds[i]]==false){
          tokenIds.push(_tokenIds[i]);
          tokenIdAdded[_tokenIds[i]]= true;
        }
        }
         if(addedToOwnerList[to]==false){
            ownerList.push(to);
            addedToOwnerList[to] = true;
        }
        verifyMaxSupply();
        return true;
    }

    function setTokenUri(uint256 tokenId, string memory uri)
        external
        onlyAdmin
    {
        _setTokenURI(tokenId, uri);
    }

    function burn(uint256 _id) external noEmergencyFreeze returns (bool) {
        removeFees(_id);
        return super.burn(msg.sender, _id);
    }

    /**
     * @dev Owner can transfer out any accidentally sent ERC20 tokens
     * @param contractAddress ERC20 contract address
     * @param to withdrawal address
     * @param value no of tokens to be withdrawan
     */
    function transferAnyERC20Token(
        address contractAddress,
        address to,
        uint256 value
    ) external onlyOwner {
        IERC20(contractAddress).transfer(to, value);
    }

    /**
     * @dev Owner can transfer out any accidentally sent ERC721 tokens
     * @param contractAddress ERC721 contract address
     * @param to withdrawal address
     * @param tokenId Id of 721 token
     */
    function withdrawAnyERC721Token(
        address contractAddress,
        address to,
        uint256 tokenId
    ) external onlyOwner {
        ERC721Basic(contractAddress).safeTransferFrom(
            address(this),
            to,
            tokenId
        );
    }

    /**
     * @dev Owner kill the smart contract
     * @param message Confirmation message to prevent accidebtal calling
     * @notice BE VERY CAREFULL BEFORE CALLING THIS FUNCTION
     * Better pause the contract
     * DO CALL "transferAnyERC20Token" before TO WITHDRAW ANY ERC-2O's FROM CONTRACT
     */
    function kill(uint256 message) external onlyOwner {
        require(message == 123456789987654321, "Invalid code");
        // Transfer Eth to owner and terminate contract
        selfdestruct(payable(msg.sender));
    }

    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    public virtual
    override
    noEmergencyFreeze
    canTransfer(_tokenId)
  {
    require(_from != address(0), "Zero address not allowed");
    require(_to != address(0), "Zero address not allowed");

    clearApproval(_from, _tokenId);
    removeTokenFrom(_from, _tokenId);
    addTokenTo(_to, _tokenId);
    if(addedToOwnerList[_to]==false&& _to!=address(0)){
            ownerList.push(_to);
            addedToOwnerList[_to] = true;
        }

    emit Transfer(_from, _to, _tokenId);
  }

   function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
    public
    override virtual
    noEmergencyFreeze
    canTransfer(_tokenId)
  
  {
    // solium-disable-next-line arg-overflow
    safeTransferFrom(_from, _to, _tokenId, "");
     if(addedToOwnerList[_to]==false&& _to!=address(0)){
            ownerList.push(_to);
            addedToOwnerList[_to] = true;
        }
  }

 
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes memory _data
  )
    public
    override virtual
    noEmergencyFreeze
    canTransfer(_tokenId)
  {
    transferFrom(_from, _to, _tokenId);
     if(addedToOwnerList[_to]==false&& _to!=address(0)){
            ownerList.push(_to);
            addedToOwnerList[_to] = true;
        }
    // solium-disable-next-line arg-overflow
    require(checkAndCallSafeTransfer(_from, _to, _tokenId, _data), "Safe Transfer failed");
  }
 function transfer(address _to, uint256 _tokenId)
    public override virtual
    noEmergencyFreeze
    returns (bool)
  {
    safeTransferFrom(msg.sender, _to, _tokenId);
     if(addedToOwnerList[_to]==false&& _to!=address(0)){
            ownerList.push(_to);
            addedToOwnerList[_to] = true;
        }
    return true;
  }

  function getAllHolders() external view returns(HolderInfo[] memory info){
       uint256 count = 0;
       uint256 total = tokenIds.length;
           for(uint256 j=0; j<total;j++){
               if(ownerOf(tokenIds[j])!= address(0)){
               count++;
           }
           }

    HolderInfo[] memory userInfo = new HolderInfo[](count);
    uint256 number=0;
           for(uint256 j=0; j<total;j++){
                 if(ownerOf(tokenIds[j])!=address(0)){
                  userInfo[number].id = j;
                  userInfo[number].user = ownerOf(j);
                  number++;
           }
           }
    return(userInfo); 

    }

}

