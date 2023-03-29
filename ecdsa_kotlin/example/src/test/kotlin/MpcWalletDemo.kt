import org.junit.Test
import org.web3j.protocol.Web3j
import org.web3j.protocol.http.HttpService
import org.web3j.tx.TransactionManager
import org.web3j.tx.response.PollingTransactionReceiptProcessor
import org.web3j.utils.Numeric
import xyz.zkme.mpc.ecdsa.MpcAlgorithm
import xyz.zkme.mpc.example.LocalServer
import xyz.zkme.mpc.example.MpcWallet
import xyz.zkme.mpc.example.mpcLogger
import java.math.BigDecimal
import java.math.BigInteger


class MpcWalletDemo {
    //LocalServer PrivateKey
    private val party1PrivateKey = BigInteger("45719149885192233806045810317315129331085385709175189237177881263558905923184")
    private val server = LocalServer(MpcAlgorithm.Additive,party1PrivateKey).apply {
        mpcLogger.debug = true
    }

    private val net = Net.polygonTest;

    @Test
    fun transferETH() {
        //Client
        val party2PrivateKey =
            "45310857711343548321619327685761206898760210185743148061608685128827704370714".toBigInteger()
        println("client PrivateKey:${Numeric.toHexString(party2PrivateKey.toByteArray())}")


        val wallet = MpcWallet.importWallet(party2PrivateKey, net.rpcUrl, net.chainId, server)
        println("MPC Wallet address ${wallet.walletAddress}")
        val toAddress = wallet.walletAddress
        val txId = wallet.transfer(toAddress, BigDecimal("0.0001"))
        val txUrl = "${net.scanUrl}/tx/$txId";
        println("================================")
        println("MPC transfer ETH txUrl:\n$txUrl")
        println("================================")
        assert(txId.isNotBlank())

//        //waitForTransaction
//        val processor = PollingTransactionReceiptProcessor(
//            Web3j.build(HttpService(net.rpcUrl)),
//            TransactionManager.DEFAULT_POLLING_FREQUENCY,
//            TransactionManager.DEFAULT_POLLING_ATTEMPTS_PER_TX_HASH
//        )
//        val transactionReceipt = processor.waitForTransactionReceipt(txId)
//        assert(transactionReceipt != null)
    }

    @Test
    fun transferErc20Token() {
        //Client
        val party2PrivateKey =
            "45310857711343548321619327685761206898760210185743148061608685128827704370714".toBigInteger()

        val wallet = MpcWallet.importWallet(party2PrivateKey, net.rpcUrl, net.chainId, server)
        println("MPC Wallet address ${wallet.walletAddress}")
        val tokenContract = "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd"
        val decimals = 18
        val toAddress = wallet.walletAddress
        val txId = wallet.transfer(toAddress, BigDecimal("0.012"), tokenContract, decimals)
        val txUrl = "${net.scanUrl}/tx/$txId";
        println("================================")
        println("MPC transfer ERC20 token txUrl:\n$txUrl")
        println("================================")
        assert(txId.isNotBlank())

//        //waitForTransaction
//        val processor = PollingTransactionReceiptProcessor(
//            Web3j.build(HttpService(net.rpcUrl)),
//            TransactionManager.DEFAULT_POLLING_FREQUENCY,
//            TransactionManager.DEFAULT_POLLING_ATTEMPTS_PER_TX_HASH
//        )
//        val transactionReceipt = processor.waitForTransactionReceipt(txId)
//        assert(transactionReceipt != null)
    }

    @Test
    fun mpcSignMessage() {
        //Client
        val party2PrivateKey =
            "45310857711343548321619327685761206898760210185743148061608685128827704370714".toBigInteger()

        val wallet = MpcWallet.importWallet(party2PrivateKey, net.rpcUrl, net.chainId, server)
        println("MPC Wallet address ${wallet.walletAddress}")

        val message = "hello".toByteArray()
        wallet.signMessage(message)

    }
}