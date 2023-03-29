package xyz.zkme.mpc.example

import com.google.gson.*
import com.n1analytics.paillier.EncryptedNumber
import com.n1analytics.paillier.PaillierPublicKey
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import org.bouncycastle.jcajce.provider.asymmetric.ec.BCECPublicKey
import org.bouncycastle.math.ec.custom.sec.SecP256K1Curve
import org.bouncycastle.util.BigIntegers
import org.web3j.utils.Numeric
import xyz.zkme.mpc.ecdsa.*
import java.math.BigInteger
import java.security.SecureRandom


///xyz.zkme.mpc.ecdsa.Party1
interface Server {
    fun createWallet(party2PubKey: BCECPublicKey): BCECPublicKey
    fun partySignMessage(
        clientPubKey: BCECPublicKey,
        messageHash: ByteArray,
        cKey: EncryptedNumber,
        R: BigInteger,
        k_2: BigInteger
    ): EncryptedNumber

    val algorithm: MpcAlgorithm

}


class LocalServer(override val algorithm: MpcAlgorithm, private val serverPrivateKey: BigInteger) :
    Server {
    companion object {
        //Key: WalletAddressHex, Value:P1
        private val walletMap = mutableMapOf<String, Party1>()

    }

    override fun createWallet(party2PubKey: BCECPublicKey): BCECPublicKey {
        val keyPair1 = Secp256k1KeyPair.importKeyPair(serverPrivateKey)
        //wallet PubKey
        Party1.from(keyPair1, party2PubKey)
        val party1 = Party1.from(keyPair1, party2PubKey, algorithm)
        walletMap.putIfAbsent(party2PubKey.getAddress(), party1)
        return party1.masterPubKey
    }

    /**
     * xyz.zkme.mpc.ecdsa.Party2 part sign message
     */
    override fun partySignMessage(
        clientPubKey: BCECPublicKey,
        messageHash: ByteArray,
        cKey: EncryptedNumber,
        R: BigInteger,
        k_2: BigInteger
    ): EncryptedNumber {
        val party1 = walletMap[clientPubKey.getAddress()]!!
        return party1.partySignMessage(messageHash, cKey, R, k_2)
    }
}

class RemoteServer(private val baseUrl: String, override val algorithm: MpcAlgorithm) : Server {

    override fun createWallet(party2PubKey: BCECPublicKey): BCECPublicKey {
        val reqBody = JsonObject().apply {
            add("publicKey", JsonPrimitive(Numeric.toHexString(party2PubKey.q.getEncoded(false))))
        }

        val data = postRequest("/thresholdSign/getPublicKey", reqBody).asString
        val pubKey = SecP256K1Curve().decodePoint(Numeric.hexStringToByteArray(data)).toEcPubKey()
        return pubKey
    }

    /**
     * xyz.zkme.mpc.ecdsa.Party2 part sign message
     */
    override fun partySignMessage(
        clientPubKey: BCECPublicKey,
        messageHash: ByteArray,
        cKey: EncryptedNumber,
        R: BigInteger,
        k_2: BigInteger
    ): EncryptedNumber {

        //request body
        val reqBody = JsonObject().apply {
            add("message", messageHash.let {
                val array = JsonArray()
                for (i in messageHash) {
                    array.add(i)
                }
                return@let array
            })
            add("cipherText", JsonPrimitive(cKey.calculateCiphertext().toString()))
            add("exponent", JsonPrimitive(cKey.exponent))
            add("k2", JsonPrimitive(k_2.toString()))
            add("modulus", JsonPrimitive(cKey.context.publicKey.modulus.toString()))
            add("r", JsonPrimitive(R.toString()))
            add("publicKey", JsonPrimitive(Numeric.toHexString(clientPubKey.q.getEncoded(false))))
        }
        //send request
        val data = postRequest("/thresholdSign/sign", reqBody) as JsonObject

        //parse response
        val c3 = data.let {
            val modulus = data.get("modulus").asBigInteger
            val cipherText = data.get("cipherText").asBigInteger
            val exponent = data.get("exponent").asInt
            return@let EncryptedNumber(
                PaillierPublicKey(modulus).createUnsignedContext(),
                cipherText, exponent, true,
            )
        }
        return c3

    }

    private fun postRequest(path: String, body: JsonObject): JsonElement {
        val gson = Gson()
        val interceptor = HttpLoggingInterceptor()
        val resp = OkHttpClient.Builder()
            .addNetworkInterceptor(interceptor)
            .build().newCall(
                Request.Builder().url("$baseUrl$path")
                    .post(gson.toJson(body).toRequestBody())
                    .build()
            ).execute()

        val bodyString = resp.body!!.string()
        val respJson = gson.fromJson(bodyString, JsonObject::class.java)
        return respJson.get("data")
    }

}


