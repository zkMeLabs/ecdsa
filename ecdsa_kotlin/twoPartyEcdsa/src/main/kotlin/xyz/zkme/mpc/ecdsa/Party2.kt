package xyz.zkme.mpc.ecdsa

import com.n1analytics.paillier.EncryptedNumber
import com.n1analytics.paillier.PaillierPrivateKey
import org.bouncycastle.jcajce.provider.asymmetric.ec.BCECPublicKey
import org.web3j.crypto.ECDSASignature
import org.web3j.crypto.Hash
import org.web3j.crypto.Sign
import org.web3j.utils.Numeric
import xyz.zkme.mpc.ecdsa.MpcAlgorithm.*
import java.math.BigInteger

abstract class Party2 internal constructor(
    val keyPair: Secp256k1KeyPair,
    val masterPubKey: BCECPublicKey
) {

    companion object {
        fun from(
            keyPair: Secp256k1KeyPair,
            otherPubKey: BCECPublicKey,
            algorithm: MpcAlgorithm,
        ): Party2 {
            val party2: Party2 = when (algorithm) {
                Additive -> _Party2_Additive(keyPair, otherPubKey)
                Multiply -> _Party2_Multiply(keyPair, otherPubKey)
            }
            return party2
        }
    }

    abstract val algorithm: MpcAlgorithm

    /**
     *  compute Sign.
     *
     * @return SignatureData(R、S、V)
     */
    abstract fun computeSignature(
        partialSig: PartialSig,
        psk: PaillierPrivateKey
    ): Sign.SignatureData

    /**
     * p1 Generates Homomorphic KeyPair(ppk,psk)
     */
    private fun generatePaillierPrivateKey(): Paillier {
        val paillierPrivateKey = PaillierPrivateKey.create(2048)
        val ppk2 = paillierPrivateKey.publicKey
        val x2 = keyPair.privateKey.d
        val cKey = ppk2.createUnsignedContext().encrypt(x2).safeEncryptedNumber
        return Paillier(paillierPrivateKey, cKey)
    }

    @Suppress("LocalVariableName")
    fun genPartialSigMessage(message: ByteArray, needToHash: Boolean = true): PartialSigMessage {
        val messageHash = if (needToHash) {
            Hash.sha3(message)
        } else {
            message
        }

        //Client psk ppk cKey
        val paillier = generatePaillierPrivateKey()
        val order = keyPair.publicKey.q.curve.order

        var R = BigInteger.ZERO
        var k1: BigInteger
        var k2: BigInteger
        while (true) {
            val keyPair1 = Secp256k1KeyPair.generateECKeyPair()
            val keyPair2 = Secp256k1KeyPair.generateECKeyPair()
            val pub1 = keyPair1.publicKey
            val pub2 = keyPair2.publicKey
            k1 = keyPair1.privateKey.d
            k2 = keyPair2.privateKey.d
            val Q_1 = pub1.q
            val Q_2 = pub2.q
            val Q_P1 = Q_2.multiply(k1).normalize()
            val R_1 = Q_P1.xCoord.toBigInteger().mod(order)
            val Q_P2 = Q_1.multiply(k2).normalize()
            val R_2 = Q_P2.xCoord.toBigInteger().mod(order)
            if (R_1.compareTo(R_2) == 0) {
                R = R_1
            }
            if (R.compareTo(BigInteger.ZERO) != 0) {
                break
            }
        }

        return PartialSigMessage(paillier, messageHash, k1, k2, R)
    }
}

@Suppress("ClassName")
private class _Party2_Multiply(keyPair: Secp256k1KeyPair, masterPubKey: BCECPublicKey) :
    Party2(keyPair, masterPubKey) {

    override val algorithm: MpcAlgorithm get() = Multiply

    /**
     *  compute Sign.
     *
     * @return SignatureData(R、S、V)
     */
    @Suppress("LocalVariableName")
    override fun computeSignature(
        partialSig: PartialSig,
        psk: PaillierPrivateKey
    ): Sign.SignatureData {
        val c3 = partialSig.encrypted
        val order = keyPair.publicKey.q.curve.order

        val k1Inv = partialSig.k1.modInverse(order)
        //# P1 decrypts c_3 with the homomorphic public key ssk to obtain S' (denoted as S_)
        val S_ = psk.decrypt(c3).decodeBigInteger()

        val S__ = k1Inv.multiply(S_).mod(order)
        val ss = order.subtract(S__)
        val S = if (S__ < ss) {
            S__
        } else {
            ss
        }

        val sig = ECDSASignature(partialSig.R, S).toCanonicalised()
        return sig.toSignatureData(masterPubKey, partialSig.messageHash)
    }
}


@Suppress("ClassName")
private class _Party2_Additive(keyPair: Secp256k1KeyPair, masterPubKey: BCECPublicKey) :
    Party2(keyPair, masterPubKey) {

    override val algorithm: MpcAlgorithm get() = Additive


    /**
     *  compute Sign.
     *
     * @return SignatureData(R、S、V)
     */
    @Suppress("LocalVariableName")
    override fun computeSignature(
        partialSig: PartialSig,
        psk: PaillierPrivateKey
    ): Sign.SignatureData {
        val c5 = partialSig.encrypted
        val order = keyPair.publicKey.q.curve.order
        val k1Inv = partialSig.k1.modInverse(order)
        val S_ = psk.decrypt(c5).decodeBigInteger()
        val S__ = k1Inv.multiply(S_).mod(order)
        val ss = order.subtract(S__)

        val S = if (S__ < ss) {
            S__
        } else {
            ss
        }

        val sig = ECDSASignature(partialSig.R, S).toCanonicalised()
        return sig.toSignatureData(masterPubKey, partialSig.messageHash)
    }
}


class Paillier(val psk: PaillierPrivateKey, val cKey: EncryptedNumber)

class PartialSigMessage(
    val paillier: Paillier,
    val messageHash: ByteArray,
    val k1: BigInteger,
    val k2: BigInteger,
    val R: BigInteger
)

class PartialSig(
    val encrypted: EncryptedNumber,
    val messageHash: ByteArray,
    val k1: BigInteger,
    val R: BigInteger
)


private fun ECDSASignature.toSignatureData(
    pubKey: BCECPublicKey,
    messageHash: ByteArray
): Sign.SignatureData {
    // Now we have to work backwards to figure out the recId needed to recover the signature.
    val recId = pubKey.ecRecoverRecId(this, messageHash)
        ?: throw RuntimeException("Could not construct a recoverable key. Are your credentials valid?")

    val v = byteArrayOf(((recId + 27).toByte()))
    val r = Numeric.toBytesPadded(r, 32)
    val s = Numeric.toBytesPadded(s, 32)
    return Sign.SignatureData(v, r, s)
}