// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISecondaryMarketFees {

  struct Fee {
    address recipient;
    uint256 value;
  }
  
  function getFeeRecipients(uint256 tokenId) external view returns(address[] memory);

  function getFeeBps(uint256 tokenId) external view returns(uint256[] memory);


}
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
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
    decimals = 3; // this makes min fee to be 0.001% for any recipient
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
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator)
        external
        view
        returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}
abstract contract ERC165 is IERC165 {
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
    constructor() {
        _registerInterface(InterfaceId_ERC165);
    }

    /**
     * @dev implement supportsInterface(bytes4) using a lookup table
     */
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override
        returns (bool)
    {
        return supportedInterfaces[_interfaceId];
    }

    /**
     * @dev private method for registering an interface
     */
    function _registerInterface(bytes4 _interfaceId) internal {
        require(_interfaceId != 0xffffffff);
        supportedInterfaces[_interfaceId] = true;
    }
}
contract HasTokenURI {
    //Token URI prefix
    string public tokenURIPrefix;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    constructor(string memory _tokenURIPrefix) {
        tokenURIPrefix = _tokenURIPrefix;
    }

    /**
     * @dev Returns an URI for a given token ID.
     * Throws if the token ID does not exist. May return an empty string.
     * @param tokenId uint256 ID of the token to query
     */
    function _tokenURI(uint256 tokenId) internal view returns (string memory) {
        return string(abi.encodePacked(tokenURIPrefix, _tokenURIs[tokenId]));
    }

    /**
     * @dev Internal function to set the token URI for a given token.
     * Reverts if the token ID does not exist.
     * @param tokenId uint256 ID of the token to set its URI
     * @param uri string URI to assign
     */
    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        _tokenURIs[tokenId] = uri;
    }

    /**
     * @dev Internal function to set the token URI prefix.
     * @param _tokenURIPrefix string URI prefix to assign
     */
    function _setTokenURIPrefix(string memory _tokenURIPrefix) internal {
        tokenURIPrefix = _tokenURIPrefix;
    }

    function _clearTokenURI(uint256 tokenId) internal {
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}
abstract contract ERC1155MetadataURI is HasTokenURI {
    constructor(string memory _tokenURIPrefix) HasTokenURI(_tokenURIPrefix) {}

    function uri(uint256 _id) external view returns (string memory) {
        return _tokenURI(_id);
    }
}
contract ERC1155 is Context, ERC165, IERC1155, ERC1155MetadataURI {
    using Address for address;

    // Token name
    string public name;

    // Token symbol
    string public symbol;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(uint256 => uint256) public tokenSupply;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory tokenURIPrefix
    ) ERC1155MetadataURI(tokenURIPrefix) {
        name = _name;
        symbol = _symbol;
        _registerInterface(type(IERC1155).interfaceId);
    }

    modifier shouldExist(uint256 tokenId) {
        require(totalSupply(tokenId) != 0, "token does not exists");
        _;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            account != address(0),
            "ERC1155: balance query for the zero address"
        );
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(
            accounts.length == ids.length,
            "ERC1155: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            from,
            to,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        uint256 fromBalance = _balances[id][from];
        require(
            fromBalance >= amount,
            "ERC1155: insufficient balance for transfer"
        );
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155: insufficient balance for transfer"
            );
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        string memory _uri
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            address(0),
            to,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        _balances[id][to] += amount;
        tokenSupply[id] += amount;
        _setTokenURI(id, _uri);
        emit TransferSingle(operator, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            id,
            amount,
            data
        );
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data,
        string[] memory _uris
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
            tokenSupply[ids[i]] += amounts[i];
            _setTokenURI(ids[i], _uris[i]);
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            ids,
            amounts,
            data
        );
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            from,
            address(0),
            _asSingletonArray(id),
            _asSingletonArray(amount),
            ""
        );

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        tokenSupply[id] -= amount;

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155: burn amount exceeds balance"
            );
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            tokenSupply[ids[i]] -= amounts[i];
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }
}
contract Freezable is Ownership {
    bool public emergencyFreeze = false;
    mapping(address => bool) private _isFreezed;

    event EmerygencyFreezed(bool emergencyFreezeStatus);
    event Freezed(address user, bool isFreezed);

    modifier noEmergencyFreeze() {
        require(!emergencyFreeze, "Contract is freezed");
        _;
    }

    modifier isUnfreezed(address user) {
        require(!isFreezed(user), "Address is freezed");
        _;
    }

    /**
     * @dev Admin can freeze/unfreeze the contract
     * Reverts if sender is not the owner of contract
     * @param _freeze Boolean valaue; true is used to freeze and false for unfreeze
     */
    function emergencyFreezeAllAccounts(bool _freeze)
        public
        onlyOwner
        returns (bool)
    {
        emergencyFreeze = _freeze;
        emit EmerygencyFreezed(_freeze);
        return true;
    }

    function freezeUser(address user) public isUnfreezed(user) onlyOwner {
        _isFreezed[user] = true;
        emit Freezed(user, true);
    }

    function unfreeze(address user) public onlyOwner {
        require(isFreezed(user), "Address is not freezed");
        _isFreezed[user] = false;
        emit Freezed(user, false);
    }

    function isFreezed(address user) public view returns (bool) {
        return _isFreezed[user];
    }
}
contract BaseERC1155 is ERC1155, Freezable {
    constructor(
        string memory _name,
        string memory _symbol,
        string memory uri
    ) ERC1155(_name, _symbol, uri) {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override isUnfreezed(from) isUnfreezed(to) {
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override isUnfreezed(from) isUnfreezed(to) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function setTokenURIPrefix(string memory tokenURIPrefix) public onlyOwner {
        _setTokenURIPrefix(tokenURIPrefix);
    }

    /**
     * @dev Public function to set the token URI for a given token.
     * Reverts if the token ID does not exist.
     * @param tokenId uint256 ID of the token to set its URI
     * @param uri string URI to assign
     */
    function setTokenURI(uint256 tokenId, string memory uri)
        public
        onlyAdmin
        shouldExist(tokenId)
    {
        super._setTokenURI(tokenId, uri);
    }

    function burn(
        uint256 id,
        uint256 amount
    ) external {
        _burn(msg.sender, id, amount);
    }

    function burnBatch(
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        _burnBatch(msg.sender, ids, amounts);
    }
}
contract CustomERC1155Collection is
    BaseERC1155,
    SecondaryMarketFee,
    MultiShareHolders
{
    uint256 public maxSupply;
    uint256 private supply_;
    // Array with all token ids, used for enumeration
    uint256[] public tokenIds;
     mapping(address => bool) public addedToOwnerList;
     address[] public ownerList;
     struct HolderInfo{
        uint256 id;
        address user;
        uint256 numberOfTokens;
    }
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address[] memory _shareHolders,
        uint256[] memory _percentageShares,
        uint256 _maxSupply
    )
        BaseERC1155(_name, _symbol, _uri)
        MultiShareHolders(_shareHolders, _percentageShares)
    {
        _registerInterface(_INTERFACE_ID_FEES);
        maxSupply = _maxSupply;
    }

    function verifyMaxSupply() private view {
        if (maxSupply > 0) require(supply_ <= maxSupply, "Max supply reached");
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        string memory _uri,
        Fee[] memory fees
    ) external onlyAdmin returns (bool) {
        if (totalSupply(id) == 0) {
            supply_ += 1;
            verifyMaxSupply();
            tokenIds.push(id);
        }
        _mint(to, id, amount, data, _uri);
        super.addFees(id, fees);
        if(addedToOwnerList[to]==false && to!=address(0)){
            ownerList.push(to);
            addedToOwnerList[to] = true;
        }
    
        return true;
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data,
        string[] memory _uris,
        Fee[] memory fees // fee is same for all ids..
    ) external onlyAdmin returns (bool) {
        uint256 batchSupply;
        for (uint256 i = 0; i < ids.length; i++) {
            if (totalSupply(ids[i]) == 0) {
                batchSupply += 1;
                tokenIds.push(ids[i]);
            }
        }
        supply_ += batchSupply;
        verifyMaxSupply();
        _mintBatch(to, ids, amounts, data, _uris);
        for (uint256 i = 0; i < ids.length; i++) {
            super.addFees(ids[i], fees);
        }

        if(addedToOwnerList[to]==false && to!=address(0)){
            ownerList.push(to);
            addedToOwnerList[to] = true;
        }
        return true;
    }

    /**
     * @dev Gets the total amount of tokens stored by the contract
     * @return uint256 representing the total amount of tokens
     */
    function totalSupply() external view returns (uint256) {
        return tokenIds.length;
    }

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

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override isUnfreezed(from) isUnfreezed(to) {
        super.safeTransferFrom(from, to, id, amount, data);
        if(addedToOwnerList[to]==false && to!=address(0)){
            ownerList.push(to);
            addedToOwnerList[to] = true;
        }
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override isUnfreezed(from) isUnfreezed(to) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
         if(addedToOwnerList[to]==false && to!=address(0)){
            ownerList.push(to);
            addedToOwnerList[to] = true;
        }
    }

    function getAllHolders() external view returns(HolderInfo[] memory info){
        uint256 count = 0;
        uint256 total = tokenIds.length;
        uint256 totalHolders = ownerList.length;
        for(uint256 i=0; i< total; i++){
           for(uint256 j=0; j<totalHolders;j++){
               if((balanceOf(ownerList[j],tokenIds[i]))>0){            
                      count++;
               }
           }
        }

    HolderInfo[] memory userInfo = new HolderInfo[](count);
    uint256 number=0;
         for(uint256 i=0; i< total; i++){
           for(uint256 j=0; j<totalHolders;j++){
                   if((balanceOf(ownerList[j],tokenIds[i]))>0){
                  userInfo[number].id = tokenIds[i];
                  userInfo[number].user = ownerList[j];
                  userInfo[number].numberOfTokens = balanceOf(ownerList[j],tokenIds[i]);
                  number++;
           }
           }
        }
    return(userInfo);

    }

    function getAllHoldersOfId(uint256 id) external view returns(HolderInfo[] memory info){
        uint256 count = 0;
        uint256 totalHolders = ownerList.length;
           for(uint256 j=0; j<totalHolders;j++){
               if((balanceOf(ownerList[j],id))>0)
               count++;
           }
        

    HolderInfo[] memory userInfo = new HolderInfo[](count);
    uint256 number=0;
           for(uint256 j=0; j<totalHolders;j++){
              if((balanceOf(ownerList[j],id))>0){
                  userInfo[number].id = id;
                  userInfo[number].user = ownerList[j];
                  userInfo[number].numberOfTokens = balanceOf(ownerList[j],id);
                  number++;
              }  
           }
    return(userInfo); 

    }
   
}
