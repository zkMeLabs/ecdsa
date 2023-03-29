import XCTest
@testable import TwoPartyEcdsa
final class TwoPartyEcdsaTests: XCTestCase {
    
    func testSignMessage()  throws {
        let keyPair1 = Secp256k1KeyPair.generate()
        let keyPair2 = Secp256k1KeyPair.generate()
        let masterPubKey = Party1.getMasterPubKey(keyPair1, keyPair2.publicKey)
        print("masterPubKey (\(masterPubKey.rawRepresentation):\(masterPubKey.rawRepresentation.bytes)");
 
        let party1 = Party1(keyPair1, masterPubKey);
        let party2 = Party2(keyPair2, masterPubKey);
        let message = "hello".data(using: .utf8)!
        
        let partialSigMessage = party2.genPartialSigMessage(message.bytes);
        let c3 = party1.partialSignMessage(messageHash:partialSigMessage.messageHash, cKey: partialSigMessage.paillier.cKey, R: partialSigMessage.R, k2: partialSigMessage.k2)
        print("c3=\(c3.ciphertext)");
        let partialSig = PartialSig.init(c3: c3, messageHash: partialSigMessage.messageHash, k1:partialSigMessage.k1, R: partialSigMessage.R)
        let msgSignature = try? party2.computeSignature(partialSig, partialSigMessage.paillier.psk)
        assert(msgSignature != nil)
        print("R=\(msgSignature!.r)");
        print("S=\(msgSignature!.s)");
        print("V=\(msgSignature!.v)");
        let isValid = masterPubKey.isValidSignature(messageHash:partialSig.messageHash, signature: msgSignature!)
        XCTAssertEqual(isValid,true)
        
    }
    
    func testEcRecoverId(){
        let keyPair1 = Secp256k1KeyPair.importPrivateKey(  BigInteger("45719149885192233806045810317315129331085385709175189237177881263558905923184")! )
        let keyPair2 = Secp256k1KeyPair.importPrivateKey(  BigInteger("45310857711343548321619327685761206898760210185743148061608685128827704370714")!)
        let masterPubKey = Party1.getMasterPubKey(keyPair1, keyPair2.publicKey)
        let message = "hello".data(using: .utf8)!
        let messageHash = Secp256k1KeyPair.genMessageHash(message.bytes)
        
        let R = BigInteger("110858528356551453607624535804464409978078603383496679132380137680736149253849")!
        let S = BigInteger("33235971164116138932401287279350878689516246566737490177962018184657790732451")!
        let recId = masterPubKey.ecRecoverId(messageHash, R, S)
    
        XCTAssertEqual(recId != nil,true)
        print("==========\n recId=\(recId!)")
    }
}
