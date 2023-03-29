//
//  Secp256k1KeyPair.swift
//  
//
//  Created by ks on 2022/11/18.
//

import Foundation
import secp256k1


public typealias PrivateKey = secp256k1.Signing.PrivateKey
public typealias PublicKey = secp256k1.Signing.PublicKey

public struct Secp256k1KeyPair{
    public let privateKey: PrivateKey
    public let publicKey: PublicKey
    
    /// Creates a random secp256k1 private key for signing
    private init(privateKey:PrivateKey)  {
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey
    }
    
    public static func generate() -> Secp256k1KeyPair{
        let privateKey = try! PrivateKey(format: .uncompressed)
        return Secp256k1KeyPair.init(privateKey: privateKey)
    }
    public  static func importPrivateKey(_ privateKey: BigInteger) -> Secp256k1KeyPair{
        let ecPrivateKey = try! PrivateKey(rawRepresentation: privateKey.asMagnitudeBytes(),format: .uncompressed)
        return Secp256k1KeyPair.init(privateKey:ecPrivateKey)
    }
    
    static var order: BigInteger {
        //secp256k1 Order
        BigInteger.init("115792089237316195423570985008687907852837564279074904382605163141518161494337")!
    }
    public var order: BigInteger {
        //secp256k1 Order
        Secp256k1KeyPair.order
    }
    
}

public struct MsgSignature{
    
    public  var r:BigInteger
    public  var s:BigInteger
    public  var v:UInt8
    
    public init(r: BigInteger, s: BigInteger, v: UInt8) {
        self.r = r
        self.s = s
        self.v = v
    }
}

public extension PublicKey{
    
    //secp256k1 Order
    var order: BigInteger {
        return  Secp256k1KeyPair.order
    }
    
    func ecRecoverId(_ messageHash: [UInt8], _ r:BigInteger, _ s:BigInteger ) -> UInt8? {
        var recId: UInt8? = nil
        let pubKey = self
        let rawHex = pubKey.rawRepresentation.bytes.toHexString()
        for i in 0...3 {
            do{
            
                let recoverPubKeyBytes = try ecRecoverPubKey(messageHash ,r,s,UInt8(i) )
                let recoverHex = recoverPubKeyBytes.toHexString()
                
                if(rawHex == recoverHex){
                    recId = UInt8(i)
                    break
                }
            } catch   {
                //next
            }
        }
        return recId ?? nil
    }
    
    func isValidSignature(messageHash:[UInt8],signature: MsgSignature) -> Bool{
        var isValid = false
        let publicKey = self
        do{
            let recId = signature.v - 27
            let recoverPubKeyBytes = try ecRecoverPubKey(messageHash ,signature.r,signature.s,UInt8(recId) )
            let rawHex = publicKey.rawRepresentation.bytes.toHexString()
            let recoverHex = recoverPubKeyBytes.toHexString()
            isValid = (rawHex == recoverHex)
        }catch{
            isValid = false
        }
        return isValid
    }
    
    private func ecRecoverPubKey(_ messageHash: [UInt8], _ r: BigInteger, _ s:BigInteger, _ recoveryId:UInt8)  throws -> [UInt8]  {
        
        let sigData:[UInt8] = r.asMagnitudeBytes().bytes + s.asMagnitudeBytes().bytes
        
        let recoverySig = try secp256k1.Recovery.ECDSASignature(compactRepresentation: Data(sigData), recoveryId: Int32(recoveryId))
        
        var pubKeyLen = self.format.length
        var pubKey = secp256k1_pubkey()
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)
        var recoverySignature = secp256k1_ecdsa_recoverable_signature()
        
        recoverySig.rawRepresentation.copyToUnsafeMutableBytes(of: &recoverySignature.data)
        
        guard secp256k1_ecdsa_recover(secp256k1.Context.raw, &pubKey, &recoverySignature, Array(messageHash))==1,
              secp256k1_ec_pubkey_serialize(secp256k1.Context.raw, &pubBytes, &pubKeyLen, &pubKey, format.rawValue)==1 else {
            throw secp256k1Error.underlyingCryptoError
        }
        
        return pubBytes
        
    }
    
    
}


public extension Secp256k1KeyPair{
    
    static func genMessageHash(_ message:[UInt8]) -> [UInt8] {
        return keccak256MessageHash( message)
    }
        
    func isValidSignature(messageHash:[UInt8],signature: MsgSignature) -> Bool{
        return self.publicKey.isValidSignature(messageHash:messageHash, signature: signature)
    }
}
