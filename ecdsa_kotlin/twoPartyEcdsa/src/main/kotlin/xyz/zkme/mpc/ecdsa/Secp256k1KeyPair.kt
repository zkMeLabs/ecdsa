package xyz.zkme.mpc.ecdsa

import org.bouncycastle.jcajce.provider.asymmetric.ec.BCECPrivateKey
import org.bouncycastle.jcajce.provider.asymmetric.ec.BCECPublicKey
import org.bouncycastle.jcajce.provider.asymmetric.util.EC5Util
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.jce.spec.ECNamedCurveGenParameterSpec
import org.bouncycastle.jce.spec.ECPrivateKeySpec
import org.bouncycastle.jce.spec.ECPublicKeySpec
import org.bouncycastle.math.ec.FixedPointCombMultiplier
import java.math.BigInteger
import java.security.AlgorithmParameters
import java.security.KeyPairGenerator
import java.security.SecureRandom
import java.security.Security
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECParameterSpec


/**
 * curve: secp256k1
 */
class Secp256k1KeyPair private constructor(
    val privateKey: BCECPrivateKey,
    val publicKey: BCECPublicKey,
) {

    companion object {
        init {
            if (null == Security.getProvider(BouncyCastleProvider.PROVIDER_NAME)) {
                //Insert BouncyCastle Provider first
                Security.addProvider(BouncyCastleProvider())
            }
        }

        const val ALGORITHM = "EC"
        const val CURVE = "secp256k1"

        fun generateECKeyPair(): Secp256k1KeyPair {
            val generator =
                KeyPairGenerator.getInstance(ALGORITHM, BouncyCastleProvider()).apply {
                    initialize(ECNamedCurveGenParameterSpec(CURVE), SecureRandom())
                }

            val keyPair = generator.generateKeyPair()
            return Secp256k1KeyPair(
                keyPair.private as BCECPrivateKey,
                keyPair.public as BCECPublicKey,
            )
        }

        fun importKeyPair(privateKey: BigInteger): Secp256k1KeyPair {
            val parameters =
                AlgorithmParameters.getInstance(ALGORITHM, BouncyCastleProvider())
                    .apply { init(ECGenParameterSpec(CURVE)) }
            val ecParameterSpec = parameters.getParameterSpec(ECParameterSpec::class.java)
            val bcEcParameterSpec = EC5Util.convertSpec(ecParameterSpec)
            val bcEcPrivateKey = BCECPrivateKey(
                ALGORITHM,
                ECPrivateKeySpec(privateKey, bcEcParameterSpec),
                BouncyCastleProvider.CONFIGURATION
            )

            val q = FixedPointCombMultiplier().multiply(bcEcParameterSpec.g, bcEcPrivateKey.d)
            val bcEcPublicKey = BCECPublicKey(
                ALGORITHM,
                ECPublicKeySpec(q, bcEcParameterSpec),
                BouncyCastleProvider.CONFIGURATION
            )
            return Secp256k1KeyPair(bcEcPrivateKey, bcEcPublicKey)
        }
    }
}
