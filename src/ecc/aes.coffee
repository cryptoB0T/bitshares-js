# https://code.google.com/p/crypto-js
class Aes

    CryptoJS = require("crypto-js")
    assert = require("assert")
    hash = require("./hash")

    constructor: (@iv, @key) ->

    Aes.fromSha512 = (hash) ->
        assert.equal hash.length, 128, "A Sha512 in HEX should be 128 characters long"
        #https://github.com/InvictusInnovations/fc/blob/978de7885a8065bc84b07bfb65b642204e894f55/src/crypto/aes.cpp#L330
        #Bitshares aes_decrypt uses part of the password hash as the initilization vector
        iv = CryptoJS.enc.Hex.parse(hash.substring(64, 96))
        key = CryptoJS.enc.Hex.parse(hash.substring(0, 64))
        new Aes(iv, key)

    Aes.fromSecret = (password) ->
        assert password, true, "password is required"
        pw_hash = hash.sha512 password
        pw_hash = pw_hash.toString('hex')
        Aes.fromSha512(pw_hash)

    decrypt_word_array: (cipher) ->
        # https://code.google.com/p/crypto-js/#Custom_Key_and_IV
        # see wallet_records.cpp master_key::decrypt_key
        CryptoJS.AES.decrypt(
          ciphertext: cipher
          salt: null
        , @key,
          iv: @iv
        )

    # HEX in / HEX out
    decrypt_hex: (cipher) ->
        # Convert data into word arrays (used by Crypto)
        cipher_array = CryptoJS.enc.Hex.parse(cipher)
        plainwords = @decrypt_word_array cipher_array
        CryptoJS.enc.Hex.stringify plainwords

exports.Aes = Aes
