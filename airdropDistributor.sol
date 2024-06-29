// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenAirdrop is Ownable(msg.sender) {
  IERC20 public token;

  constructor(address tokenAddress) {
    token = IERC20(tokenAddress);
  }

  /**
   * @dev Distributes the token to a list of addresses with corresponding amounts.
   * @param recipients The addresses of the recipients.
   * @param amounts The amounts of tokens each recipient should receive.
   */
  function distributeTokens(
    address[] calldata recipients,
    uint256[] calldata amounts
  ) external onlyOwner {
    require(
      recipients.length == amounts.length,
      "Recipients and amounts do not match"
    );
    for (uint i = 0; i < recipients.length; i++) {
      require(
        token.transferFrom(msg.sender, recipients[i], amounts[i]),
        "Failed to transfer tokens"
      );
    }
  }

  /**
   * @dev Withdraws tokens from the contract to the owner's address.
   * @param amount The amount of tokens to withdraw.
   */
  function withdrawTokens(uint256 amount) external onlyOwner {
    require(token.transfer(msg.sender, amount), "Failed to withdraw tokens");
  }
}
