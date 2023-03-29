//  Paillier.swift
//  Created by Simon Kempendorf on 07.02.19.
//
import Foundation
 
public final class Paillier {
    public static let defaultKeysize = 2048
    
    private let privateKey: PrivateKey
    public let publicKey: PublicKey
    
    public init(strength: Int = Paillier.defaultKeysize) {
        let keyPair = Paillier.generateKeyPair(strength)
        privateKey = keyPair.privateKey
        publicKey = keyPair.publicKey
    }
    
    public init(keyPair: KeyPair) {
        self.privateKey = keyPair.privateKey
        self.publicKey = keyPair.publicKey
    }
    
    public func L(x: BigInteger, p: BigInteger) -> BigInteger {
        return (x-1)/p
    }
    
    
    public func decrypt(ciphertext: BigInteger, type: DecryptionType = .bigIntDefault) -> BigInteger {
        switch type {
        case .bigIntFast:
            let mp = (L(x: ciphertext.power(privateKey.p - 1, modulus: privateKey.psq), p: privateKey.p) * privateKey.hp) % privateKey.p
            let mq = (L(x: ciphertext.power(privateKey.q - 1, modulus: privateKey.qsq), p: privateKey.q) * privateKey.hq) % privateKey.q
            
            // Solve using Chinese Remainder Theorem
            let u = (mq-mp) * privateKey.pinv
            return mp +  (u % privateKey.q) * privateKey.p
        case .bigIntDefault:
            
            let lambda = (privateKey.p-1)*(privateKey.q-1)
            let mu = L(x: publicKey.g.power(lambda, modulus: publicKey.nsq), p: publicKey.n).inverse(publicKey.n)
            return (L(x: ciphertext.power(lambda, modulus: publicKey.nsq), p: publicKey.n) * mu) % publicKey.n
            //        case .bigNumFast:
            //            let ciphertext = Bignum(ciphertext.description)
            //            let mp = (L(x: mod_exp(ciphertext, privateKey.pnum - 1, privateKey.psqnum), p: privateKey.pnum) * privateKey.hpnum) % privateKey.pnum
            //            let mq = (L(x: mod_exp(ciphertext, privateKey.qnum - 1, privateKey.qsqnum), p: privateKey.qnum) * privateKey.hqnum) % privateKey.qnum
            //
            //            // Solve using Chinese Remainder Theorem
            //            let u = (mq-mp) * privateKey.pinvnum
            //            return BInt((mp + ((u % privateKey.qnum) * privateKey.pnum)).string())!
            //        case .bigNumDefault:
            //            let ciphertext = Bignum(ciphertext.description)
            //            let lambda = (privateKey.pnum-1)*(privateKey.qnum-1)
            //            let mu = inverse(L(x: mod_exp(publicKey.gnum, lambda, publicKey.nsqnum), p: publicKey.nnum), publicKey.nnum)!
            //            return BInt(((L(x: mod_exp(ciphertext, lambda, publicKey.nsqnum), p: publicKey.nnum) * mu) % publicKey.nnum).string())!
        }
    }
    
    public func decrypt(_ encryption: PaillierEncryption, type: DecryptionType = .bigIntDefault) -> BigInteger {
        return decrypt(ciphertext: encryption.ciphertext, type: type)
    }
    
    public func encrypt(_ plaintext: BigInteger) -> PaillierEncryption {
        return PaillierEncryption(plaintext, for: publicKey)
    }
    
    public enum DecryptionType {
        case bigIntDefault
        case bigIntFast
        //        case bigNumDefault
        //        case bigNumFast
    }
}

// MARK: Keys and their handling
public extension Paillier {
    struct KeyPair {
        public let privateKey: PrivateKey
        public let publicKey: PublicKey
    }
    
    struct PublicKey {
        let n: BigInteger
        let g: BigInteger
        
        // MARK: Precomputed values
        let nsq: BigInteger
        //        let nnum: Bignum
        //        let gnum: Bignum
        //        let nsqnum: Bignum
        
        init(n: BigInteger, g: BigInteger) {
            self.n = n
            self.g = g
            nsq = n.power(2)
            //            nnum = Bignum(n.description)
            //            gnum = Bignum(g.description)
            //            nsqnum = Bignum(nsq.description)
        }
    }
    
    struct PrivateKey {
        let p: BigInteger
        let q: BigInteger
        
        // MARK: Precomputed values
        let psq: BigInteger
        let qsq: BigInteger
        let hp: BigInteger
        let hq: BigInteger
        let pinv: BigInteger
        
        //        let pnum: BInt
        //        let qnum: BInt
        //        let psqnum: BInt
        //        let qsqnum: BInt
        //        let hpnum: BInt
        //        let hqnum: BInt
        //        let pinvnum: BInt
        
        init(p: BigInteger, q: BigInteger, g: BigInteger) {
            self.p = p
            self.q = q
            psq = p.power(2)
            qsq = q.power(2)
            hp = Paillier.h(on: g, p: p, psq: psq)
            hq = Paillier.h(on: g, p: q, psq: qsq)
            pinv = p.inverse(q)
            
            //            pnum = Bignum(p.description)
            //            qnum = Bignum(q.description)
            //            psqnum = Bignum(psq.description)
            //            qsqnum = Bignum(qsq.description)
            //            hpnum = Bignum(hp.description)
            //            hqnum = Bignum(hq.description)
            //            pinvnum = Bignum(pinv.description)
        }
    }
    
    static func h(on g: BigInteger, p: BigInteger, psq: BigInteger) -> BigInteger {
        let parameter = g.power(p-1, modulus: psq) % psq
        let lOfParameter = (parameter-1)/p
        return lOfParameter.inverse(p)
    }
    
    static func generatePrime(_ width: Int) -> BigInteger {
        while true {
            var random = BigInteger.probablePrime(width)
            if(random.isEven){
                random |= BigInteger(1)
            }
             if random.isProbablyPrime() {
                 return random
            }
        }
    }
    
    static func generateKeyPair(_ strength: Int = Paillier.defaultKeysize) -> KeyPair {
      
        var p, q: BigInteger
        print("start generateKeyPair=\(Date.init())")
        p = generatePrime(strength/2)
        print("end generate P\(Date.init()) p =\(p) ")
        repeat {
            q = generatePrime(strength/2)
        } while p == q
        print("end generate \(Date.init()) q =\(q) ")
        if q < p {
            swap(&p, &q)
        }
        
        
        let n = p*q
        let g = n+1
        
        let privateKey = PrivateKey(p: p, q: q, g: g)
        let publicKey = PublicKey(n: n, g: g)
        return KeyPair(privateKey: privateKey, publicKey: publicKey)
    }
}


public class PaillierEncryption {
    private var _ciphertext: BigInteger
    public var ciphertext: BigInteger {
        get {
            if !isBlinded {
                blind()
            }
            return _ciphertext
        }
    }
    private var isBlinded: Bool
    public let publicKey: Paillier.PublicKey
    
    public init(_ plaintext: BigInteger, for publicKey: Paillier.PublicKey) {
        self.publicKey = publicKey
        self._ciphertext = BigInteger.ZERO
        self.isBlinded = false
        encrypt(plaintext)
    }
    
    public init(ciphertext: BigInteger, for publicKey: Paillier.PublicKey) {
        self.publicKey = publicKey
        self._ciphertext = ciphertext
        isBlinded = false
    }
    
    private func encrypt(_ plaintext: BigInteger) {
        let plaintextnum = plaintext
        _ciphertext = rawEncrypt(plaintextnum)
        isBlinded = false
    }
    
    private func rawEncrypt(_ plaintext: BigInteger) -> BigInteger {
        // Shortcut solution:
        return (plaintext * publicKey.n + 1) % publicKey.nsq
        
        // General (default) solution:
        // _ciphertext = publicKey.g.power(plaintext, modulus: publicKey.nsq)
    }
    
    
    func mod_exp(base:BigInteger,pow:Int,mod:BigInteger) -> BigInteger{
        return   base.power(pow) % mod
    }
    
    private func rawBlind(_ ciphertext: BigInteger) -> BigInteger {
        
        
        let r =  publicKey.n.randomLessThan()
        let cipher = ciphertext * (r.power(publicKey.n,modulus: publicKey.nsq))
        return cipher % publicKey.nsq
        
    }
    
    public func blind() {
        _ciphertext = rawBlind(_ciphertext)
        isBlinded = true
    }
    
    @discardableResult
    public func add(_ scalar: BigInteger) -> PaillierEncryption {
        let ciphertext = rawEncrypt(scalar)
        add(ciphertext: ciphertext)
        return self
    }
    
    @discardableResult
    public func subtract(_ scalar: BigInteger) -> PaillierEncryption {
        let ciphertext = rawEncrypt(scalar)
        subtract(ciphertext: ciphertext)
        return self
    }
    
    //    @discardableResult
    //    public func add(_ scalar: BInt) -> PaillierEncryption {
    //        let ciphertext = rawEncrypt(scalar)
    //        add(ciphertext: ciphertext)
    //        return self
    //    }
    //
    //    @discardableResult
    //    public func subtract(_ scalar: BInt) -> PaillierEncryption {
    //        let ciphertext = rawEncrypt(scalar)
    //        subtract(ciphertext: ciphertext)
    //        return self
    //    }
    
    //    @discardableResult
    //    public func subtract(ciphertext: BInt) -> PaillierEncryption {
    //        subtract(ciphertext:ciphertext)
    //        return self
    //    }
    
    //    @discardableResult
    //    public func add(ciphertext: BInt) -> PaillierEncryption {
    //        add(ciphertext: Bignum(ciphertext.description))
    //        return self
    //    }
    
    @discardableResult
    public func subtract(ciphertext: BigInteger) -> PaillierEncryption {
        
        add(ciphertext:  ciphertext.inverse(publicKey.nsq))
        return self
    }
    
    @discardableResult
    public func add(ciphertext: BigInteger) -> PaillierEncryption {
        _ciphertext = (_ciphertext * ciphertext) % publicKey.nsq
        isBlinded = false
        return self
    }
    
    //    @discardableResult
    //    public func multiply(_ scalar: BInt) -> PaillierEncryption {
    //        multiply(Bignum(scalar.description))
    //        return self
    //    }
    
    @discardableResult
    public func multiply(_ scalar: BigInteger) -> PaillierEncryption {
        _ciphertext =  _ciphertext.power(scalar, modulus: publicKey.nsq)
        isBlinded = false
        return self
    }
}


extension BigInteger{
    func power(_ p:Int) -> BigInteger{
        return self ** p
    }
    func power(_ exponent:BigInteger,modulus:BigInteger) -> BigInteger{
        return self.expMod(exponent, modulus)
    }
    func inverse( _ modulus:BigInteger) -> BigInteger{
        return self.modInverse(modulus)
    }
}



