package xyz.zkme.mpc.example

import org.bouncycastle.jcajce.provider.asymmetric.ec.BCECPublicKey
import org.web3j.abi.FunctionEncoder
import org.web3j.abi.TypeReference
import org.web3j.abi.datatypes.Address
import org.web3j.abi.datatypes.Bool
import org.web3j.abi.datatypes.Function
import org.web3j.abi.datatypes.generated.Uint256
import org.web3j.crypto.RawTransaction
import org.web3j.crypto.Sign.SignatureData
import org.web3j.crypto.TransactionEncoder
import org.web3j.protocol.Web3j
import org.web3j.protocol.core.DefaultBlockParameterName
import org.web3j.protocol.core.methods.request.Transaction
import org.web3j.protocol.http.HttpService
import org.web3j.rlp.RlpEncoder
import org.web3j.rlp.RlpList
import org.web3j.utils.Convert
import org.web3j.utils.Numeric
import xyz.zkme.mpc.ecdsa.*
import java.math.BigDecimal
import java.math.BigInteger

/**
 * Party2
 */
open class MpcWallet(
    private val party2: Party2,
    private val rpcUrl: String,
    private val chainId: Long,
    private val server: Server
) {

    /**
     * MPC Wallet Address
     */
    val walletAddress: String get() = walletPubKey.getAddress()
    private val walletPubKey: BCECPublicKey get() = party2.masterPubKey

    companion object {
        fun generateWallet(
            rpcUrl: String,
            chainId: Long,
            server: Server
        ): MpcWallet {
            val keyPair2 = Secp256k1KeyPair.generateECKeyPair()
            val walletPubKey = server.createWallet(keyPair2.publicKey)
            return MpcWallet(
                Party2.from(keyPair2, walletPubKey, server.algorithm),
                rpcUrl,
                chainId,
                server
            )
        }

        fun importWallet(
            privateKey: BigInteger,
            rpcUrl: String,
            chainId: Long,
            server: Server
        ): MpcWallet {
            val keyPair2 = Secp256k1KeyPair.importKeyPair(privateKey)
            val walletPubKey = server.createWallet(keyPair2.publicKey)
            return MpcWallet(
                Party2.from(keyPair2, walletPubKey, server.algorithm),
                rpcUrl,
                chainId,
                server
            )
        }

    }


    private fun ethTransferTransaction(
        web3j: Web3j,
        amount: BigDecimal,
        fromAddress: String,
        toAddress: String,
        contractAddress: String? = null,
        decimals: Int? = null,
    ): RawTransaction {
        val balance =
            web3j.ethGetBalance(fromAddress, DefaultBlockParameterName.LATEST).send().balance
        val ethBalance = Convert.fromWei(balance.toBigDecimal(), Convert.Unit.ETHER)
        val gasPrice = web3j.ethGasPrice().send().gasPrice
        val nonce = web3j.ethGetTransactionCount(fromAddress, DefaultBlockParameterName.PENDING)
            .send().transactionCount

        mpcLogger.info("Current balance $balance , $ethBalance ETH")
        mpcLogger.info("gasPrice $gasPrice")
        mpcLogger.info("nonce $nonce")

        when {
            contractAddress?.isNotBlank() == true -> {
                //transfer ERC20 token
                val sendAmount = amount.multiply(BigDecimal.TEN.pow(decimals!!)).toBigInteger()
                println("send amount $amount ERC20, value:$sendAmount ")
                val function = erc20TransferFunction(toAddress, sendAmount)
                val encodedFunction = FunctionEncoder.encode(function)
                val gasLimit = web3j.ethEstimateGas(
                    Transaction.createFunctionCallTransaction(
                        fromAddress,
                        nonce,
                        gasPrice,
                        null,
                        contractAddress,
                        encodedFunction
                    )
                ).send().amountUsed

                return RawTransaction.createTransaction(
                    nonce,
                    gasPrice,
                    gasLimit,
                    contractAddress,
                    BigInteger.ZERO,
                    encodedFunction
                )
            }

            else -> {
                //transfer ETH
                val gasLimit = BigInteger.valueOf(21000)
                val sendAmount = Convert.toWei(amount, Convert.Unit.ETHER).toBigInteger()
                mpcLogger.info("send amount $amount Eth, value:$sendAmount (WEI)")
                return RawTransaction.createEtherTransaction(
                    nonce,
                    gasPrice,
                    gasLimit,
                    toAddress,
                    sendAmount
                )
            }
        }


    }

    private fun erc20TransferFunction(to: String, value: BigInteger): Function = Function(
        "transfer",
        listOf(Address(to), Uint256(value)), listOf(object : TypeReference<Bool>() {})
    )

    /**
     * Send ETH or erc20 token
     */
    fun transfer(
        toAddress: String,
        amount: BigDecimal,
        contractAddress: String? = null,
        decimals: Int? = null
    ): String {
        val httpService = HttpService(rpcUrl)
        val web3j = Web3j.build(httpService)
        //Transaction
        val rawT = ethTransferTransaction(
            web3j,
            amount,
            walletAddress,
            toAddress,
            contractAddress,
            decimals
        )
        val encodedTransaction = TransactionEncoder.encode(rawT, chainId)

        //Sign Transaction
        val signatureData = signMessage(encodedTransaction)
        val eip155SignatureData =
            TransactionEncoder.createEip155SignatureData(signatureData, chainId)
        val values = TransactionEncoder.asRlpValues(rawT, eip155SignatureData)
        val rlpList = RlpList(values)
        val signedMessage = RlpEncoder.encode(rlpList)
        val hexValue = Numeric.toHexString(signedMessage)
        mpcLogger.info("signedMessage HexValue: $hexValue")
        //Send
        val result = web3j.ethSendRawTransaction(hexValue).send()
        return result.transactionHash
    }


    fun signMessage(message: ByteArray, needToHash: Boolean = true): SignatureData {
        val partialSigMessage = party2.genPartialSigMessage(message, needToHash)

        // Server party Sign
        val encrypted = server.partySignMessage(
            party2.keyPair.publicKey,
            partialSigMessage.messageHash,
            partialSigMessage.paillier.cKey,
            partialSigMessage.R,
            partialSigMessage.k2,
        )

        //Client compute Sign
        val msgSignature = party2.computeSignature(
            PartialSig(
                encrypted,
                partialSigMessage.messageHash,
                partialSigMessage.k1,
                partialSigMessage.R
            ),
            partialSigMessage.paillier.psk
        )

        val validSignature =
            walletPubKey.isValidSignature(partialSigMessage.messageHash, msgSignature)
        mpcLogger.info("validSignature:$validSignature");
        return msgSignature

    }

}

