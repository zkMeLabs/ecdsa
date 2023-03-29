package xyz.zkme.mpc.ecdsa

import org.bouncycastle.jcajce.provider.asymmetric.ec.BCECPublicKey
import org.bouncycastle.jcajce.provider.asymmetric.util.EC5Util
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.jce.spec.ECPublicKeySpec
import org.bouncycastle.math.ec.ECPoint
import org.web3j.crypto.ECDSASignature
import org.web3j.crypto.Keys
import org.web3j.crypto.Sign
import java.math.BigInteger
import java.security.AlgorithmParameters
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECParameterSpec

fun ECPoint.toEcPubKey(curve: String = Secp256k1KeyPair.CURVE): BCECPublicKey {
    val parameters =
        AlgorithmParameters.getInstance(Secp256k1KeyPair.ALGORITHM, BouncyCastleProvider())
            .apply { init(ECGenParameterSpec(curve)) }
    val ecParameterSpec = parameters.getParameterSpec(ECParameterSpec::class.java)
    val bcEcParameterSpec = EC5Util.convertSpec(ecParameterSpec)
    return BCECPublicKey(
        Secp256k1KeyPair.ALGORITHM,
        ECPublicKeySpec(this, bcEcParameterSpec),
        BouncyCastleProvider.CONFIGURATION
    )
}

fun BCECPublicKey.getAddress(): String {
    val pubKey = Sign.publicFromPoint(this.q.getEncoded(false))
    var address = Keys.getAddress(pubKey)
    //check 0x...
    address = Keys.toChecksumAddress(address)
    return address
}


fun BCECPublicKey.ecRecoverRecId(sig: ECDSASignature, messageHash: ByteArray): Int? {
    // Now we have to work backwards to figure out the recId needed to recover the signature.
    var recId: Int? = null
    val walletPubKey = Sign.publicFromPoint(q.getEncoded(false))
    for (i in 0..3) {
        val k: BigInteger? = Sign.recoverFromSignature(i, sig, messageHash)
        if (k != null && k == walletPubKey) {
            recId = i
            break
        }
    }
    return recId
}

fun BCECPublicKey.isValidSignature(
    messageHash: ByteArray,
    msgSignature: Sign.SignatureData
): Boolean {
    return try {
        val findPubKey = Sign.signedMessageHashToKey(messageHash, msgSignature)
        val pubKey = Sign.publicFromPoint(this.q.getEncoded(false))
        findPubKey == pubKey
    } catch (e: Exception) {
        false
    }
}