import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Creator registration flow with reward tiers",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'register-creator', [
                types.ascii("Test Creator")
            ], creator.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify creator data with new fields
        let getCreator = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'get-creator-data', [
                types.principal(creator.address)
            ], creator.address)
        ]);
        
        const creatorData = getCreator.receipts[0].result.expectOk().expectSome();
        assertEquals(creatorData['name'], "Test Creator");
        assertEquals(creatorData['total-views'], types.uint(0));
        assertEquals(creatorData['engagement-score'], types.uint(0));
        assertEquals(creatorData['reward-tier'], types.uint(1));
    },
});

Clarinet.test({
    name: "Video engagement and rewards flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator = accounts.get('wallet_1')!;
        const viewer = accounts.get('wallet_2')!;
        
        // Register creator
        let setup = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'register-creator', [
                types.ascii("Test Creator")
            ], creator.address)
        ]);
        
        // Publish video
        let publish = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'publish-video', [
                types.ascii("Test Video"),
                types.ascii("Test Description")
            ], creator.address)
        ]);
        
        const videoId = publish.receipts[0].result.expectOk();
        
        // Record view, like and comment
        let engagement = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'record-view', [
                videoId
            ], viewer.address),
            Tx.contractCall('streamo_platform', 'like-video', [
                videoId
            ], viewer.address),
            Tx.contractCall('streamo_platform', 'comment-video', [
                videoId
            ], viewer.address)
        ]);
        
        engagement.receipts[0].result.expectOk().expectBool(true);
        engagement.receipts[1].result.expectOk().expectBool(true);
        engagement.receipts[2].result.expectOk().expectBool(true);
        
        // Verify video data
        let getVideo = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'get-video-data', [
                videoId
            ], viewer.address)
        ]);
        
        const videoData = getVideo.receipts[0].result.expectOk().expectSome();
        assertEquals(videoData['views'], types.uint(1));
        assertEquals(videoData['likes'], types.uint(1));
        assertEquals(videoData['comments'], types.uint(1));
    },
});

Clarinet.test({
    name: "Reward tiers functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator = accounts.get('wallet_1')!;
        
        // Get reward tier info
        let tierInfo = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'get-reward-tier', [
                types.uint(1)
            ], creator.address)
        ]);
        
        const tierData = tierInfo.receipts[0].result.expectOk().expectSome();
        assertEquals(tierData['name'], "Bronze");
        assertEquals(tierData['multiplier'], types.uint(1));
        assertEquals(tierData['threshold'], types.uint(0));
    },
});
