package xyz.zkme.mpc.ecdsa

import com.n1analytics.paillier.EncryptedNumber
import org.bouncycastle.jcajce.provider.asymmetric.ec.BCECPublicKey
import org.bouncycastle.util.BigIntegers
import xyz.zkme.mpc.ecdsa.MpcAlgorithm.*
import java.math.BigInteger
import java.security.SecureRandom

abstract class Party1 internal constructor(
    val keyPair: Secp256k1KeyPair,
    val masterPubKey: BCECPublicKey
) {


    companion object {
        fun from(
            keyPair: Secp256k1KeyPair,
            otherPubKey: BCECPublicKey,
            algorithm: MpcAlgorithm = Additive
        ): Party1 {
            val party1: Party1 = when (algorithm) {
                Additive -> _Party1_Additive.from(keyPair, otherPubKey)
                Multiply -> _Party1_Multiply.from(keyPair, otherPubKey)
            }
            return party1
        }
    }

    abstract val algorithm: MpcAlgorithm

    abstract fun partySignMessage(
        messageHash: ByteArray,
        cKey: EncryptedNumber,
        R: BigInteger,
        k2: BigInteger
    ): EncryptedNumber


}

@Suppress("ClassName")
private class _Party1_Multiply private constructor(
    keyPair: Secp256k1KeyPair,
    masterPubKey: BCECPublicKey,
    override val algorithm: MpcAlgorithm = Multiply,
) : Party1(keyPair, masterPubKey) {
    companion object {
        internal fun from(keyPair: Secp256k1KeyPair, otherPubKey: BCECPublicKey): _Party1_Multiply {
            val pubKey = otherPubKey.q.multiply(keyPair.privateKey.d).normalize()
            val ecPubKey = pubKey.toEcPubKey(Secp256k1KeyPair.CURVE)
            return _Party1_Multiply(keyPair, ecPubKey)
        }
    }

    override fun partySignMessage(
        messageHash: ByteArray,
        cKey: EncryptedNumber,
        R: BigInteger,
        k2: BigInteger
    ): EncryptedNumber {
        val ppk = cKey.context.publicKey
        val x1 = keyPair.privateKey.d
        val order = keyPair.publicKey.q.curve.order

        val z = BigInteger(1, messageHash)

        val pho = BigIntegers.createRandomInRange(BigInteger.ZERO, order.pow(2), SecureRandom())

        val k2Inv = k2.modInverse(order) //# P2 calculates the inverse of k_2 on p
        val xx = k2Inv.multiply(z).mod(order)
        val tmp = pho.multiply(order).add(xx)
        val c1: EncryptedNumber = ppk.createUnsignedContext().encrypt(tmp)
        val v = k2Inv.multiply(R).multiply(x1).mod(order)
        val c2: EncryptedNumber = cKey.multiply(v)

        @Suppress("UnnecessaryVariable")
        val c3 = c2.add(c1)
        return c3

    }
}

@Suppress("ClassName")
private class _Party1_Additive private constructor(
    keyPair: Secp256k1KeyPair,
    masterPubKey: BCECPublicKey,
    override val algorithm: MpcAlgorithm = Additive,
) : Party1(keyPair, masterPubKey) {
    companion object {
        internal fun from(keyPair: Secp256k1KeyPair, otherPubKey: BCECPublicKey): _Party1_Additive {
            val pubKey = keyPair.publicKey.q.add(otherPubKey.q).normalize()
            val ecPubKey = pubKey.toEcPubKey(Secp256k1KeyPair.CURVE)
            return _Party1_Additive(keyPair, ecPubKey)
        }
    }

    override fun partySignMessage(
        messageHash: ByteArray,
        cKey: EncryptedNumber,
        R: BigInteger,
        k2: BigInteger,
    ): EncryptedNumber {
        val ppk = cKey.context.publicKey
        val x1 = keyPair.privateKey.d
        val order = keyPair.publicKey.q.curve.order
        val z = BigInteger(1, messageHash)
        val pho = BigIntegers.createRandomInRange(BigInteger.ZERO, order.pow(2), SecureRandom())
        val k2Inv = k2.modInverse(order) //# P2 calculates the inverse of k_2 on p
        val xx = k2Inv.multiply(z).mod(order)
        val tmp = pho.multiply(order).add(xx)
        val context = ppk.createUnsignedContext()
        val c1 = context.encrypt(tmp)
        val c2 = context.encrypt(x1)
        val c3 = cKey.add(c2)
        val v = k2Inv.multiply(R).mod(order)
        val c4 = c3.multiply(v)

        @Suppress("UnnecessaryVariable")
        val c5 = c1.add(c4)
        return c5
    }
}

