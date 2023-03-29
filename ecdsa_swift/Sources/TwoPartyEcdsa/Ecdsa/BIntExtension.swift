//
//  File.swift
//  
//
//  Created by ks on 2022/11/18.
//

import Foundation

public extension  BigInteger {
    
    //    func  modInverse(_ modulus:MyBInt) -> MyBInt {
    //      return self.inverse(modulus)
    //    }
    func  multiply(_ a:BigInteger) -> BigInteger {
        
        return self * a
    }
    //    func  mod2(_ m:MyBInt) -> MyBInt {
    //
    //      return self % m
    //    }
    
    func  add(_ a:BigInteger) -> BigInteger {
        return self + a
    }
    func subtract(_ a:BigInteger) -> BigInteger {
        return self - a
    }
    static let zero = BigInteger.ZERO
}

public extension [UInt8]{
    func toBigInteger() -> BigInteger {
        return BigInteger.init(magnitude: self)
    }
}
