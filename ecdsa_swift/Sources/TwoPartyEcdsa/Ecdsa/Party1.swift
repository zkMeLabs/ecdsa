//
//  File.swift
//  
//
//  Created by ks on 2022/11/18.
//

import Foundation

public struct Party1{
    public let keyPair:Secp256k1KeyPair
    public let masterPubKey: PublicKey
    
    public init(_ keyPair: Secp256k1KeyPair, _ masterPubKey:  PublicKey) {
        self.keyPair = keyPair
        self.masterPubKey = masterPubKey
    }
    
    public static func getMasterPubKey(_ keyPair:Secp256k1KeyPair, _ publicKey: PublicKey) -> PublicKey {
        //MPC Wallet PubKey
        let masterPubKey = try! publicKey.multiply(keyPair.privateKey.rawRepresentation.bytes,format:      publicKey.format)
        return masterPubKey;
    }
    
    //server partialSignMessage
    public func partialSignMessage(messageHash:[UInt8], cKey:PaillierEncryption, R:BigInteger, k2:BigInteger) -> PaillierEncryption{
        let ppk = cKey.publicKey;
        let x1 =  keyPair.privateKey.rawRepresentation.bytes.toBigInteger()
        let order = keyPair.order
        let z = messageHash.bytes.toBigInteger()
        let pho = order.power(2).randomLessThan()
        let k2Inv = k2.modInverse(order);
        let xx = k2Inv.multiply(z).mod(order);
        let tmp = pho.multiply(order).add(xx);
        
        let c_1 = PaillierEncryption(tmp, for:ppk)
        let v = k2Inv.multiply(R).multiply(x1).mod(order);
        let c_2 = cKey.multiply(v);
        let c_3 =   c_2.add(ciphertext: c_1.ciphertext)
        return c_3
    }
}
