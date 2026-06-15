# Implementation Plan: Song Locking, Reward Locking, and Reassignment

## Objective
Implement administrative controls in `CarbonOpus.sol` to allow songs to be locked/unlocked, prevent purchases and reward claims for locked songs, and enable the reassignment of songs to new members in case of copyright disputes.

## Key Files & Context
- `contracts/interface/ICarbonOpus.sol`: Defines the `Song` struct, custom errors, and events.
- `contracts/CarbonOpus.sol`: The main implementation logic for song creation, purchases, and rewards.
- `test/CarbonOpus.test.ts` (New): A new dedicated test file to verify the specific logic of `CarbonOpus.sol`.

## Phase 1: Struct Updates and Interface Changes
1. **Update `Song` Struct**: Add a `bool locked;` flag to the `Song` struct in `ICarbonOpus.sol`.
2. **Add Custom Errors**: 
   - `error SongLocked(uint256 tokenId);`
3. **Add Events**:
   - `event SongLockStatusUpdated(uint256 indexed tokenId, bool locked);`
   - `event SongReassigned(uint256 indexed tokenId, bytes32 indexed oldMemberId, bytes32 indexed newMemberId, address newMemberAddress);`
4. **Update Initialization**: Ensure `createMusic` initializes the `locked` property to `false`.

## Phase 2: Purchasing Protections
1. **Purchase Checks**: Add checks in `purchaseMusic`, `purchaseMusicOnBehalf`, and `_getTotalCostOfBatch` to revert with `SongLocked` if the song is currently locked. This ensures no new purchases can be made for locked songs.

## Phase 3: Per-Song Reward Tracking and Locking
1. **New Mapping**: Introduce a `mapping (uint256 => uint256) public songRewards;` mapping in `CarbonOpus.sol` to track accumulated rewards on a *per-song* basis for artists, rather than globally in `rewards[memberId]`.
2. **Update Payment Distribution**: In `_distributePayment`, update the artist's share to accrue to `songRewards[tokenId]` instead of `rewards[memberId]`. Referrer and Treasury rewards remain unchanged.
3. **Update Claiming**: Modify `claimRewards` to iterate through the member's `_memberSongsCreated`. If a song is **not locked**, add its `songRewards` to the claimable amount and reset it to zero. If locked, those specific rewards remain untouchable.
4. **Update `getRewards`**: Adjust the `getRewards` view function to accurately reflect the claimable balance by summing the member's global rewards (from referrals) and the rewards from their *unlocked* songs.

## Phase 4: Reassignment Logic
1. **Toggle Lock State**: Add an `updateSongLockStatus(uint256 tokenId, bool locked)` function restricted to the `_controller` to lock or unlock a song.
2. **Reassign Song**: Add a `reassignSong(uint256 tokenId, bytes32 newMemberId, address oldMemberAddress, address newMemberAddress)` function restricted to the `_controller` or `owner`.
3. **Reassignment Flow**:
   - Update the song's `memberId`.
   - Move the `tokenId` from the old member's `_memberSongsCreated` array to the new member's array.
   - **Historical Rewards**: Because rewards are now tracked per song, any unclaimed historical rewards will seamlessly and automatically be claimable by the new owner!
   - **NFT Transfer**: Perform an internal `_update` to transfer the minted NFT from the old member's address to the new member's address, bypassing standard approval checks (since this is an administrative override).
4. **Update `_update` logic**: Ensure `_update` correctly modifies the `_memberSongsOwned` array for regular token transfers, so ownership tracking remains accurate during the administrative transfer.

## Phase 5: Verification & Testing
1. **Create `CarbonOpus.test.ts`**: Create a standalone Hardhat test suite that focuses exclusively on `CarbonOpus.sol` using standard `ethers.getContractFactory` deployments to avoid the `PhoenixDex` gas estimation issues found in the existing `000_deploy.js` scripts.
2. **Test Cases**:
   - Verify purchasing fails when a song is locked.
   - Verify artists cannot claim rewards from locked songs, but can claim from unlocked ones.
   - Verify reassigning a song transfers the NFT balance, updates ownership arrays, and allows the new owner to claim previously accrued historical rewards.
