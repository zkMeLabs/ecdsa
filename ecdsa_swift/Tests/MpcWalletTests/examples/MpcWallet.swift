import TwoPartyEcdsa
import Foundation
import Web3
public class MpcWallet {
    public let party2:Party2
    public let rpcUrl:String
    public let chainId:Int
    public let server:Server
    
    private  init(_ party2: Party2,_ rpcUrl: String,_ chainId: Int,_ server: Server) {
        self.party2 = party2
        self.rpcUrl = rpcUrl
        self.chainId = chainId
        self.server = server
    }
    
    static func importWallet(_ privateKey: BigInteger,_ rpcUrl: String,_ chainId: Int,_ server: Server) async -> MpcWallet {
        let keyPair2 = Secp256k1KeyPair.importPrivateKey(privateKey)
        let walletPubKey = await server.createWallet(keyPair2.publicKey);
        let party2 = Party2(keyPair2, walletPubKey);
        return MpcWallet( party2,   rpcUrl,   chainId,  server);
        
    }
    
    
    public var walletAddress: EthereumAddress {
        let address = try! EthereumPublicKey(_walletPubKey.rawRepresentation).address
        
        return address
    }
    
    private var _walletPubKey: PublicKey {
        return party2.masterPubKey
    }
    ///transfer , return txId
    public func transfer(toAddress:EthereumAddress, amount:Double,contractAddress:EthereumAddress?=nil, decimals:Int?=nil) async throws -> String {
        let web3 = Web3(rpcURL: rpcUrl,rpcId: chainId)
        //create Transaction
        let transaction = try! await createTransaction(web3: web3, amount: amount, fromAddress: walletAddress, toAddress: toAddress,contractAddress:contractAddress,decimals: decimals)
        print("createTransaction finish")
        
        let message = try! transaction.encode(chainId)
        let msgSignature = await signMessage(message)
        print("signMessage finish")
        let signedTx = msgSignature.toSignedTransaction(t: transaction, chainId: chainId)
        let tx = try! await web3.eth.sendRawTransaction(transaction: signedTx).async()
        let txId = tx.hex()
        return txId
    }
    
    public func signMessage(_ message:[UInt8], _ needToHash:Bool=true) async -> MsgSignature{
        let partialSigMessage = party2.genPartialSigMessage(message,needToHash)
        let messageHash = partialSigMessage.messageHash
        let R = partialSigMessage.R
        
        print("partialSignMessage start")
        //Request Server Partial Sign
        let c3 = await server.partialSignMessage(clientPubKey: party2.keyPair.publicKey, messageHash: messageHash, cKey: partialSigMessage.paillier.cKey, R: R, k2: partialSigMessage.k2)
        print("partialSignMessage finish")

        print("computeSignature start")
        //Client compute Sign
        let partialSig = PartialSig(c3: c3, messageHash:messageHash, k1: partialSigMessage.k1, R: R)
        let msgSignature = try! party2.computeSignature(partialSig, partialSigMessage.paillier.psk)
        print("computeSignature finish")

        let validSignature = _walletPubKey.isValidSignature(messageHash:messageHash, signature: msgSignature)
        
        print("validSignature:\(validSignature)");
        return msgSignature
        
    }
    
}


private extension MsgSignature{
    func toSignedTransaction(t:EthereumTransaction,chainId:Int) -> EthereumSignedTransaction{
        let r =  BigUInt("\(self.r)")!
        let s =  BigUInt("\(self.s)")!
        var v =  BigUInt("\(self.v)")!
        print("signed: v:\(v)")
        print("signed: r:\(r)")
        print("signed: s:\(s)")
        
        
        if(t.transactionType == .legacy){
            let sigV = BigUInt("\(self.v)")!
            let chainIdCalc = (BigUInt(chainId) * BigUInt(2) + BigUInt(8))
            v = sigV  + chainIdCalc
        }else{
            let sigV = BigUInt("\(self.v)")!
            v = sigV-BigUInt(27)
        }
        
        
        
        
        print("  v:\(v)")
        print("  r:\(r)")
        print("  s:\(s)")
        
        let signedTx = EthereumSignedTransaction(
            nonce: t.nonce!,
            gasPrice: t.gasPrice!,
            maxFeePerGas:t.maxFeePerGas,
            maxPriorityFeePerGas:t.maxPriorityFeePerGas,
            gasLimit: t.gasLimit!,
            to: t.to,
            value: t.value!,
            data: t.data,
            v: EthereumQuantity(quantity: v),
            r: EthereumQuantity(quantity: r),
            s: EthereumQuantity(quantity: s),
            chainId:EthereumQuantity(quantity:BigUInt(chainId)),
            accessList: t.accessList,
            transactionType: t.transactionType
        )
        return signedTx
    }
}
