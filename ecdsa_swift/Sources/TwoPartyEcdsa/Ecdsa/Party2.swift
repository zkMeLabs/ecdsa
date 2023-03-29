import Foundation
import secp256k1

public struct Party2{
    public let keyPair:Secp256k1KeyPair
    public let masterPubKey: PublicKey
    
    public init(_ keyPair: Secp256k1KeyPair, _ masterPubKey:  PublicKey) {
        self.keyPair = keyPair
        self.masterPubKey = masterPubKey
    }
    
    public func genPartialSigMessage(_ message: [UInt8], _ needToHash:Bool = true) -> PartialSigMessage{
        let messageHash: [UInt8]
        
        if(needToHash){
            messageHash = Secp256k1KeyPair.genMessageHash(message.bytes)
        }else{
            messageHash = message
        }
        
        //Client psk ppk cKey
        let paillier = _generatePaillierShareKey();
        print("_generatePaillierShareKey finish")
        let order = keyPair.order
        //gen R k1 k2
        var R = BigInteger.zero;
        var k1 =  BigInteger.zero;
        var k2 =  BigInteger.zero;
        
        while (true) {
            let key1 = Secp256k1KeyPair.generate().privateKey
            let key2 = Secp256k1KeyPair.generate().privateKey
            let pub1 = key1.publicKey
            let pub2 = key2.publicKey
            let s1 = key1.rawRepresentation.bytes.toBigInteger()
            let s2 = key2.rawRepresentation.bytes.toBigInteger()
            k1 = s1;
            k2 = s2;
            let q1 = pub1;
            let q2 = pub2;
            
            let qP1 = try! q2.multiply(k1.asMagnitudeBytes().bytes,format: q2.format)
            let r1 =  qP1.xonly.bytes.toBigInteger() % order
            let qP2 = try!  q1.multiply(k2.asMagnitudeBytes().bytes,format: q1.format);
            let r2 =  qP2.xonly.bytes.toBigInteger() % order
            
            
            if (r1 == r2) {
                R = r1;
            }
            if (R != BigInteger.zero) {
                break;
            }
        }
        
        let partiSigMessage = PartialSigMessage.init(paillier: paillier, messageHash:messageHash, k1:k1, k2:k2, R: R)
        return partiSigMessage
    }
    
    /// p2 GeneratesA Homomorphic KeyPair(ppk,psk)
    private func  _generatePaillierShareKey() -> PaillierKeyPair {
        let paillier = Paillier.init()
        print("Paillier.init finish")
        let ppk = paillier.publicKey
        let x2 =  keyPair.privateKey.rawRepresentation.bytes.toBigInteger()
        //.encrypt(x2)
        let cKey = PaillierEncryption(x2, for:ppk)
        return PaillierKeyPair(paillier, cKey);
    }
    
    public func computeSignature( _ partialSig: PartialSig , _ psk: Paillier) throws -> MsgSignature {
        let order = keyPair.order
        let k1Inv =  partialSig.k1.inverse(order)
        let _s =  psk.decrypt(partialSig.c3)
        let __s = k1Inv.multiply(_s).mod(order)
        let ss = order.subtract(__s)
        var S = BigInteger.zero
        
        if (__s < ss) {
            S = __s;
        } else {
            S = ss;
        }
        let R = partialSig.R
        
        
        print("computeSignature R=\(R)");
        print("computeSignature S=\(S)");
        
        let recId = masterPubKey.ecRecoverId(partialSig.messageHash, R, S)
        if(recId == nil){
            throw secp256k1Error.underlyingCryptoError
        }
        let V = recId! + 27;
        let msgSignature = MsgSignature(r: R, s:S, v: V)
        return msgSignature
    }
}



public struct PaillierKeyPair{
    public let psk:Paillier
    public let cKey:PaillierEncryption
    
    public init(_ psk: Paillier, _ cKey: PaillierEncryption) {
        self.psk = psk
        self.cKey = cKey
    }
}

public struct PartialSigMessage{
    public let paillier: PaillierKeyPair
    public let messageHash: [UInt8]
    public let k1: BigInteger
    public let k2: BigInteger
    public let R: BigInteger
    
    public init(paillier: PaillierKeyPair, messageHash: [UInt8], k1: BigInteger, k2: BigInteger, R: BigInteger) {
        self.paillier = paillier
        self.messageHash = messageHash
        self.k1 = k1
        self.k2 = k2
        self.R = R
    }
}

public struct PartialSig{
    public let c3:PaillierEncryption
    public let messageHash: [UInt8]
    public let k1: BigInteger
    public let R: BigInteger
    
    public init(c3: PaillierEncryption, messageHash: [UInt8], k1: BigInteger, R: BigInteger) {
        self.c3 = c3
        self.messageHash = messageHash
        self.k1 = k1
        self.R = R
    }
}
