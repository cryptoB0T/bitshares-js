{Rpc} = require "../lib/rpc_json"
{Aes} = require '../../src/ecc/aes'
{Wallet} = require '../../src/wallet/wallet'
{WalletDb} = require '../../src/wallet/wallet_db'
{WalletAPI} = require '../../src/client/wallet_api'
{PublicKey} = require '../../src/ecc/key_public'

secureRandom = require 'secure-random'

TestUtil = require './test_util'
new_wallet_api=TestUtil.new_wallet_api
config = require '../../src/config'

#GUEST_PUBLIC = "XTS7jRHZWW4t13BY277BQeyb7w8CctBeYJPZPmaaWLm4ayEvivc51"
#GUEST_ADDY = "XTSHuYaPn3GfFtABee3k6r3o9MfYwzHv4MEC"
PASSWORD = "Password00"
PAY_FROM = "delegate0" #(if p=process.env.PAY_FROM then p else "delegate0")

### 
balance delegate0
wallet_market_order_list USD XTS
###

describe "Markets", ->
    
    beforeEach ()->
        RPC_DEBUG=process.env.RPC_DEBUG
        RPC_DEBUG=off if RPC_DEBUG is undefined
        @rpc=new Rpc(RPC_DEBUG, 45000, "localhost", "test", "test")
    
    afterEach ->
        @rpc.close()
    
    it "short", (done) ->
        # wallet_market_submit_short delegate0 200 XTS 1 USD 0.01
        wallet_api = new_wallet_api @rpc
        wallet_api.market_submit_short(
            "delegate0",(""+200*3),"XTS","1","USD","0.01"
        ).then (result)->
            #console.log '... result', result
            done()
        .done()
    
    it "ask", (done) ->
        # wallet_market_submit_ask delegate0 100 XTS 0.01 USD
        wallet_api = new_wallet_api @rpc
        wallet_api.market_submit_ask(
            "delegate0",(""+200*3),"XTS","0.01","USD"
        ).then (result)->
            #console.log '... result', result
            done()
        .done()
    
    it "cover", (done) ->
        # wallet_market_cover delegate0 .5 USD xxxxxx
        @timeout (
            config.BTS_BLOCKCHAIN_BLOCK_INTERVAL_SEC * blocks + 3
        ) * 1000
        TestUtil.try_tryagain done,blocks=2,=>
            @rpc.request(
                'blockchain_list_address_orders'
                ['USD','XTS','XTS8DvGQqzbgCR5FHiNsFf8kotEXr8VKD3mR']
            ).then (result)=>
                result = result.result
                #console.log '... result',JSON.stringify result,null,1
                cover_orders = for order in result
                    continue unless order[1].type is "cover_order"
                    order
                if cover_orders.length is 0
                    return no#throw new Error "No cover_order"
                order_id = cover_orders[0][0]
                #console.log '... cover_orders',JSON.stringify cover_orders,null,1
                wallet_api = new_wallet_api @rpc
                wallet_api.market_cover(
                    "delegate0","1","USD",order_id
                ).then (result)->
                    console.log '... market_cover result', JSON.stringify result,null,1
                    return yes
    
    it "bid", (done) ->
        # wallet_market_submit_bid delegate0 0.01 USD 100 XTS
        wallet_api = new_wallet_api @rpc
        wallet_api.market_submit_bid(
            "delegate0",(""+100*1),"XTS","0.01","USD"
        ).then (result)->
            #console.log '... result', result
            done()
        .done()