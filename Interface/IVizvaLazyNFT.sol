//SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ILazyNFT {
    //represent the event emited after redeeming a voucher
    event NFTRedeemed(uint256 tokenId, address minter, address redeemer);

    /// @notice create new NFT.
    /// @param minter address to which new token is minted.
    /// @param tokenId id of the new token.
    /// @param uri uri string for the new NFT.
    function redeem(
        address minter,
        uint256 tokenId,
        string memory uri
    ) external;
}
