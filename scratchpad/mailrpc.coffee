console.log "-------------------"
RPC_PORT=process.argv[2] or 45000
console.log "(param 1) RPC_PORT=",RPC_PORT

Ecc = require '../src/ecc'
Aes = Ecc.Aes
Signature = Ecc.Signature
PrivateKey = Ecc.PrivateKey
PublicKey = Ecc.PublicKey

_Mail = require '../src/mail'
Mail = _Mail.Mail
Email = _Mail.Email
EncryptedMail = _Mail.EncryptedMail

{Rpc} = require "../test/lib/rpc_json"
{RpcCommon} = require "./rpc_common"

ByteBuffer = require 'bytebuffer'
common = require "../src/common"
q = require 'q'

@rpc=new Rpc(debug=on, RPC_PORT, "localhost", "test", "test")
@rpc_common=new RpcCommon(@rpc)

class TestNet

    WEB_ROOT=process.env.WEB_ROOT
    console.log "(param 1) WEB_ROOT=",WEB_ROOT

    WALLET_JSON="#{WEB_ROOT}/test/testnet/config/wallet.json"

    constructor: (@rpc, @rpc_common) ->

    unlock: ->
        @rpc.run """
            open default
            unlock 9999 Password00
        """

    mkdefault: ->
        @rpc.run """
            wallet_backup_restore #{WALLET_JSON} default Password00
        """

        
###
   check: ->
       @rpc.run("mail_get_processing_messages").then (response) ->
           for x in response
               if x[1] == @message_id
                   console.log "check (status) ", x[0]

###

class MailTest
    
    constructor: (@rpc, @rpc_common) ->
    
    send: ->
        @rpc.run("mail_send", ["delegate0", "delegate1", "Subject", 
        """
        Body
        end of transmission
        """]).then (response) ->
            @message_id = response
            console.log "Submitted Message ID",message_id

    inbox: ->
        @rpc.run "mail_inbox"

    processing: =>
        @rpc.run("mail_get_processing_messages").then (response) ->
            for x in response
                console.log "processing_message", x

    processing_cancel_all: ->
        #https://github.com/BitShares/bitshares_toolkit/commit/57d04e8fb2b0dda15623e83a6855f77b2dc1cbd6
        @rpc.run("mail_get_processing_messages").then (response) ->
            for x in response
                console.log("mail_cancel_message #{x[1]}")
                @rpc.run("mail_cancel_message #{x[1]}")

    configure_mail_servers: ->
        #TODO, merge public_data
        ###
        open default
        unlock 9999 Password00
        
        # wallet_account_update_registration ....
        
        enable mail server in config.json
        
        
        # All accounts default to init0 as there mail server
        wallet_account_create init0
        wallet_account_register init0 delegate0 {"mail_server_endpoint":"127.0.0.1:45000"}
        
        transfer 1 XTS delegate0 delegate1 "my memo" vote_random # mail transaction notice
        mail_send delegate0 delegate1 subject body
        
        #retry if needed
        blockchain_get_account delegate0
        blockchain_get_account delegate1
        blockchain_get_account init0
        mail_get_processing_messages
        mail_retry_send 09af...
        mail_check_new_messages
        mail_inbox
        ###
        
        # Setup for this>>> mail_send delegate0 delegate1 subject body
        public_data =
            mail_servers: ["delegate1"]
            mail_server_endpoint: "127.0.0.1:#{RPC_PORT}"

        delegate_pay_rate="100"
        @rpc.run("wallet_account_update_registration", ["delegate1", "delegate1", public_data, delegate_pay_rate]).then () ->
            # !!! this did not run ???
            @rpc.run("wallet_set_preferred_mail_servers", ["delegate0", ["delegate1"], "delegate0"])

    time: () ->
        now = new Date()
        now.setSeconds now.getSeconds() - 1 # timestamp_in_future
        now = now.toISOString()
        now = now.replace /[-:]/g, ''
        now = now.split('.')[0]
        
    mail_store_message: () ->
        now = @time()
        encrypted_mail =
            type: "encrypted"
            recipient: "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj"
            nonce: 474
            timestamp: now
            data: "020833bf65535826d249a4ff66ac4643ba6d9ae256790bf5d127f380cf3c5ce2f2a001636588df76269f78eda0d98453a5e16266317ed78ae9bb013898b4cbf52ddf54959aaf2a4b0ffa4ac4dcd52edcfe179c0127bd8b02e90ba60697a34ac2a40ed6a5adf997d5f49952a9c274f018f8d9331228749a9bd899b7bcf3f52bbb7a4c1ada1e062885767fc11ceb70f72751ce86a484096a1d2e32d7cafd23469d207da2ec535b9c971b9923ca2a7db902f627a47f654435a1ccf7d822293386d69d5f50"

        #enc = EncryptedMail.fromHex encrypted_mail.data
        @rpc.run "mail_store_message", [encrypted_mail]
        
    mail_store_message: (msg) ->
        ###
        to_server = 
            mail 'encrypted', 'XTS Recipient', nonce, time, data =
                encrypted_mail otk, cipher =
                    encrypt sign email subject, body, replyto(ripemd 20 bytes), attach, sig
        ###
        
        aes = Aes.fromSecret 'Password00'
        otk_private = PrivateKey.fromHex aes.decryptHex msg.otk_encrypted
        otk_public_compressed = otk_private.toPublicKey()
        console.log 'otk\t',otk_public_compressed.toBtsPublic()
        otk_public_uncompressed = otk_public_compressed.toUncompressed()
        
        d0_private = PrivateKey.fromHex aes.decryptHex  msg.delegate0_private_key_encrypted
        
        d1_private = PrivateKey.fromHex aes.decryptHex  msg.delegate1_private_key_encrypted
        
        # blockchain::address
        delegate0 = "XTS8DvGQqzbgCR5FHiNsFf8kotEXr8VKD3mR"
        delegate1 = "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj"
        
        Email email = new Email msg.subject, msg.body
        email.signature = Signature.signHex email.toHex(include_signature=false), d0_private
        email.subject = "Break Signature!!"
        #console.log "email\t\t",email.toHex(include_signature=true)
        
        encrypted_mail = ->
            S = d1_private.sharedSecret otk_public_uncompressed
            aes = Aes.fromSharedSecret_ecies S
            recipient = d1_private.toPublicKey().toBlockchainAddress()
            #console.log "recipient\t",recipient.toString('hex')
            Mail mail = new Mail 'email', recipient, {low: 1234}, new Date(), email.toBuffer()
            mail_hex = mail.toHex()
            cipher_hex = aes.encryptHex mail_hex
            #console.log "cipher_hex\t",cipher_hex
            cipher_buffer = new Buffer(cipher_hex, 'hex')
            new EncryptedMail otk_public_compressed, cipher_buffer
        encrypted_mail = encrypted_mail()
        #console.log "encrypted_mail\t",encrypted_mail.toHex()
        mail_json =
            type: "encrypted"
            recipient: delegate1
            nonce: 1234
            timestamp: @time()
            data: encrypted_mail.toHex()
        
        @rpc.run "mail_store_message", [mail_json]
        
    ## Authenticated
    mail_fetch_inventory:->
        delegate0 = "XTS8DvGQqzbgCR5FHiNsFf8kotEXr8VKD3mR"
        delegate1 = "XTS2Kpf4whNd3TkSi6BZ6it4RXRuacUY1qsj"
        delegate1_pub = "XTS65gij4i7BTUsoxXwuyVPGvJDj5CyAtqgJuvkXy9b5e5DkWLXQK"
        params=[
            delegate1
            "20141007T105500" #last_check_time
            1000 # BTS_MAIL_CLIENT_MAX_INVENTORY_SIZE
        ]
        defer = q.defer()
        @rpc.run("mail_fetch_inventory", params).then (result) ->
            console.log "mail_fetch_inventory",result

        defer.promise
    
    decrypt: ->
        
###
open default
unlock 9999 Password00

mail_send delegate0 init0 subject body

mail_get_processing_messages
mail_check_new_messages 

wallet_set_preferred_mail_servers "delegate0"  ["init0"] "delegate0"
wallet_set_preferred_mail_servers "delegate1"  ["init0"] "delegate1"
blockchain_get_account delegate1

mail_inbox
mail_fetch_message ... #encrypted
mail_get_message ...  #unencrypted
mail_retry_send "b784d94a16fdca48fcd90eeaad08cd861fac259f"

###

Test = =>
    msg =
        subject: 'MySubject'
        body: 'MyBody'
        id: '1318b251281fcb2d1c8e7171de5e170ffed630c6'
        pow: '000baf5bff3e8e45522e11c4780b7e93d1fb5a54'
        delegate0_private_key_encrypted: '5e1ae410919c450dce1c476ae3ed3e5fe779ad248081d85b3dcf2888e698744d0a4b60efb7e854453bec3f6883bcbd1d'
        otk_encrypted: '71121a664417626851da46f3faab898cb800012461763a07efe0e90844a48755a30e08d41cd552a6bb8ddd0afba845d3'
        otk_bts_public: 'XTS6W974oE6TmGfZZxR53znSD88ozq8zVRoD5UiPfErYYuCMsjS5K'
        delegate1_private_key_encrypted: "7b23c16519ed6bb0bbbdec47c71fdcc7881a9628c06aa9520067a49ad0ab9c0f1cb6793d2059fc15480a21abde039220"

    tn=new TestNet(@rpc, @rpc_common)
    tn.unlock()

    ## Edit tmp/client000/config.json  -> "mail_server_enabled": true

    m=new MailTest(@rpc, @rpc_common)
    #m.send()
    #m.configure_mail_servers()
    m.mail_store_message()
    #m.mail_store_message msg
    
    #m.processing_cancel_all()
    
    #m.clear()
    #m.mail_fetch_inventory()
    #m.processing()
    #m.inbox()

Test()

@rpc.close()

