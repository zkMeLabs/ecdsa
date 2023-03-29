import XCTest
@testable import TwoPartyEcdsa
import Web3
import Web3PromiseKit


final class MpcWalletTest: XCTestCase {
    func testSendEth() async throws  {
        let net = EvmNet.bscTest
 
        let clientPrivateKey = BigInteger("45310857711343548321619327685761206898760210185743148061608685128827704370714")!
        let wallet = await MpcWallet.importWallet(clientPrivateKey,net.rpcUrl, net.chainId, MockLocalServer())
        print("MPC Wallet address \(wallet.walletAddress.hex(eip55: false))");
        print("MPC Wallet Account Url: \("\(net.scanUrl)/address/\(wallet.walletAddress.hex(eip55: false))")");
        
        let toAddress = wallet.walletAddress
        let txId = try! await wallet.transfer(toAddress: toAddress, amount: 0.12)
        
        print("txId:\(txId)")
        
        let txUrl = "\(net.scanUrl)/tx/\(txId)";
        print("================================");
        print("MPC transfer ETH txUrl:\n\(txUrl)");
        print("================================");
        
        XCTAssertEqual(txId.isEmpty,false);
    }
    
    func  testSendErc20Token() async throws  {
        let net = EvmNet.bscTest
 
        let clientPrivateKey = BigInteger("45310857711343548321619327685761206898760210185743148061608685128827704370714")!
        let wallet = await MpcWallet.importWallet(clientPrivateKey,net.rpcUrl, net.chainId, MockLocalServer())
        print("MPC Wallet address \(wallet.walletAddress.hex(eip55: false))");
        print("MPC Wallet Account Url: \("\(net.scanUrl)/address/\(wallet.walletAddress.hex(eip55: false))")");
        
        let toAddress = wallet.walletAddress
        let erc20 = try! EthereumAddress(hex: "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd", eip55: false)
        let decimals = 18
        
        let txId = try! await wallet.transfer(toAddress: toAddress, amount: 0.12,contractAddress: erc20,decimals: decimals)
        
        print("txId:\(txId)")
        
        let txUrl = "\(net.scanUrl)/tx/\(txId)";
        print("================================");
        print("MPC transfer Erc20 Token txUrl:\n\(txUrl)");
        print("================================");
        
        XCTAssertEqual(txId.isEmpty,false);
    }
        
}
