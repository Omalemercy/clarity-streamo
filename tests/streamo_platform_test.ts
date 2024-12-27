import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Creator registration flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'register-creator', [
                types.ascii("Test Creator")
            ], creator.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify creator data
        let getCreator = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'get-creator-data', [
                types.principal(creator.address)
            ], creator.address)
        ]);
        
        const creatorData = getCreator.receipts[0].result.expectOk().expectSome();
        assertEquals(creatorData['name'], "Test Creator");
        assertEquals(creatorData['total-views'], types.uint(0));
    },
});

Clarinet.test({
    name: "Video publishing and viewing flow",
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
        
        // Record view
        let view = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'record-view', [
                videoId
            ], viewer.address)
        ]);
        
        view.receipts[0].result.expectOk().expectBool(true);
        
        // Verify video data
        let getVideo = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'get-video-data', [
                videoId
            ], viewer.address)
        ]);
        
        const videoData = getVideo.receipts[0].result.expectOk().expectSome();
        assertEquals(videoData['views'], types.uint(1));
    },
});

Clarinet.test({
    name: "Tipping flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const creator = accounts.get('wallet_1')!;
        const tipper = accounts.get('wallet_2')!;
        
        // Setup creator and video
        let setup = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'register-creator', [
                types.ascii("Test Creator")
            ], creator.address),
            Tx.contractCall('streamo_platform', 'publish-video', [
                types.ascii("Test Video"),
                types.ascii("Test Description")
            ], creator.address)
        ]);
        
        const videoId = setup.receipts[1].result.expectOk();
        
        // Tip creator
        let tip = chain.mineBlock([
            Tx.contractCall('streamo_platform', 'tip-creator', [
                videoId,
                types.uint(100)
            ], tipper.address)
        ]);
        
        tip.receipts[0].result.expectOk().expectBool(true);
    },
});