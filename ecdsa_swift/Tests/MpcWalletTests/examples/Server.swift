import Foundation
import TwoPartyEcdsa

public protocol Server{
    ///create Master PubKey
    func createWallet(_ clientPubKey:PublicKey) async -> PublicKey
    
    
    ///partial sign message, Retuen c3
    func partialSignMessage(clientPubKey:PublicKey, messageHash:[UInt8], cKey: PaillierEncryption,R:BigInteger,k2:BigInteger) async -> PaillierEncryption
}



public class MockLocalServer:Server{
    private static var _walletMap = [String: Party1]()
    public func createWallet(_ clientPubKey: PublicKey) async ->  PublicKey {
        let privateKey = BigInteger("45719149885192233806045810317315129331085385709175189237177881263558905923184")!
        let keyPair = Secp256k1KeyPair.importPrivateKey( privateKey)
        let pubKey = Party1.getMasterPubKey(keyPair, clientPubKey)
        let party1 = Party1(keyPair,pubKey)
        MockLocalServer._walletMap[clientPubKey.rawRepresentation.toHexString()] = party1
        return pubKey
        
    }
    
    public func partialSignMessage(clientPubKey:  PublicKey, messageHash: [UInt8], cKey:  PaillierEncryption, R:  BigInteger, k2:  BigInteger) async ->  PaillierEncryption {
        let party1 =  MockLocalServer._walletMap[clientPubKey.rawRepresentation.toHexString()]!
        return party1.partialSignMessage(messageHash: messageHash, cKey: cKey, R: R, k2: k2)
    }        
}

