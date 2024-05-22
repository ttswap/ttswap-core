// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./interfaces/I_Proof.sol";
import {S_ProofKey} from "./libraries/L_Struct.sol";
import {L_Proof, L_ProofIdLibrary} from "./libraries/L_Proof.sol";
import {L_ArrayStorage} from "./libraries/L_ArrayStorage.sol";

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ERC721Utils} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol";

abstract contract ProofManage is I_Proof, ERC165 {
    using L_Proof for *;
    using Strings for uint256;
    using L_ProofIdLibrary for S_ProofKey;
    using L_ArrayStorage for L_ArrayStorage.S_ArrayStorage;

    // Token name
    string private constant _name = "TTSWAP NFT";

    // Token symbol
    string private constant _symbol = "TTN";
    uint256 public override totalSupply;
    mapping(uint256 => L_Proof.S_ProofState) internal proofs;
    mapping(address => L_ArrayStorage.S_ArrayStorage) internal ownerproofs;
    mapping(bytes32 => uint256) public proofseq;
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    modifier onlyOwner(uint256 proofid) {
        require(proofs[proofid].owner == msg.sender, "only owner");
        _;
    }

    modifier onlyApproval(uint256 proofid) {
        require(proofs[proofid].owner == msg.sender || proofs[proofid].approval == msg.sender, "only approval");
        _;
    }

    constructor() {}

    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 proofId) external view onlyOwner(proofId) returns (string memory) {
        return string.concat("http://www.tt-swap.com/nft721?id=", proofId.toString());
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `proofId`. Empty
     * by default, can be overridden in child contracts.
     */
    function balanceOf(address owner) external view returns (uint256) {
        return ownerproofs[owner].key;
    }

    function ownerOf(uint256 proofId) external view returns (address) {
        return proofs[proofId].owner;
    }

    function tokenByIndex(uint256 _index) external pure returns (uint256) {
        return _index;
    }

    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        return ownerproofs[_owner].key_value[_index];
    }

    /// @inheritdoc I_Proof
    function getProofId(S_ProofKey calldata _investproofkey) external view override returns (uint256 proof_) {
        proof_ = proofseq[_investproofkey.toId()];
    }

    function name() external pure returns (string memory) {
        return _name;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function approve(address to, uint256 proofId) external onlyApproval(proofId) {
        proofs[proofId]._approve(to);
        emit Approval(msg.sender, to, proofId);
    }

    function getApproved(uint256 proofId) external view returns (address) {
        return proofs[proofId].approval;
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 proofid) public onlyApproval(proofid) {
        ownerproofs[from].removevalue(proofid);
        ownerproofs[to].addvalue(proofid);
        proofs[proofid].owner = to;
        proofs[proofid].approval = address(0);
        proofs[proofid].beneficiary = address(0);
        emit Transfer(from, to, proofid);
    }

    function safeTransferFrom(address from, address to, uint256 proofid) external {
        safeTransferFrom(from, to, proofid, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(msg.sender, from, to, tokenId, data);
    }

    /// @inheritdoc I_Proof
    function getProofState(uint256 _proof) external view override returns (L_Proof.S_ProofState memory proof_) {
        proof_.owner = proofs[_proof].owner;
        proof_.currentgood = proofs[_proof].currentgood;
        proof_.valuegood = proofs[_proof].valuegood;
        proof_.state = proofs[_proof].state;
        proof_.invest = proofs[_proof].invest;
        proof_.valueinvest = proofs[_proof].valueinvest;
    }

    /// @inheritdoc I_Proof
    function changeProofOwner(uint256 _proofid, address _to) external override returns (bool) {
        require(msg.sender == proofs[_proofid].owner || msg.sender == proofs[_proofid].approval, "P1");
        proofs[_proofid].owner = _to;
        return true;
    }
}
