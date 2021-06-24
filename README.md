## Tokenized Vesting
> An implementation of tokenized vesting mechanism

### Problem

Today, some projects have a system of gov token vesting schedule which which allows users of the protocol to vest the tokens in some duration. This is good for the projects but not the best for the protocol users (who receive the vested tokens). Today, there is no way for a user to trade his "locked" vesting tokens position with any other address.

### Solution

The solution is to tokenize each vesting schedule for a user into an NFT. The holder of the NFT receives (can claim) the vested tokens. It makes it possible for a user to trade his/her vesting schedule with others in an easy way. 

To make the token position (NFT) issuance cheap, the [implementation](./contracts/TokenizedVesting.sol) uses a merkletree based mechanism to allow the users to mint the tokens themselves on the first claim.