//
//  HMACAlgorithm.swift
//  HotsReplayUploader
//
//  Created by Gabriel N on 12/04/15.
//  Copyright (c) 2015 Gabriel N. All rights reserved.
//

import Foundation

enum HMACAlgorithm {
    case MD5, SHA1, SHA224, SHA256, SHA384, SHA512
    
    func toCCHmacAlgorithm() -> CCHmacAlgorithm {
        var result: Int = 0
        switch self {
        case .MD5:
            result = kCCHmacAlgMD5
        case .SHA1:
            result = kCCHmacAlgSHA1
        case .SHA224:
            result = kCCHmacAlgSHA224
        case .SHA256:
            result = kCCHmacAlgSHA256
        case .SHA384:
            result = kCCHmacAlgSHA384
        case .SHA512:
            result = kCCHmacAlgSHA512
        }
        return CCHmacAlgorithm(result)
    }
    
    func digestLength() -> Int {
        var result: CInt = 0
        switch self {
        case .MD5:
            result = CC_MD5_DIGEST_LENGTH
        case .SHA1:
            result = CC_SHA1_DIGEST_LENGTH
        case .SHA224:
            result = CC_SHA224_DIGEST_LENGTH
        case .SHA256:
            result = CC_SHA256_DIGEST_LENGTH
        case .SHA384:
            result = CC_SHA384_DIGEST_LENGTH
        case .SHA512:
            result = CC_SHA512_DIGEST_LENGTH
        }
        return Int(result)
    }
}

extension String {
    
    func hmac(algorithm: HMACAlgorithm, key: String) -> String {
        let str = self.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = Int(self.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        let digestLen = algorithm.digestLength()
        let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
        let objcKey = key as NSString
        let keyStr = objcKey.cStringUsingEncoding(NSUTF8StringEncoding)
        let keyLen = Int(objcKey.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        
        CCHmac(algorithm.toCCHmacAlgorithm(), keyStr, keyLen, str!, strLen, result)
        
        var hash = NSMutableString()
        var hashData = NSMutableData(bytes: result, length: digestLen)
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.destroy()
        
        return String(hash)
    }
    
    func hmacData(algorithm: HMACAlgorithm, key: String) -> NSData {
        let str = self.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = Int(self.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        let digestLen = algorithm.digestLength()
        let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
        let objcKey = key as NSString
        let keyStr = objcKey.cStringUsingEncoding(NSUTF8StringEncoding)
        let keyLen = Int(objcKey.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        
        CCHmac(algorithm.toCCHmacAlgorithm(), keyStr, keyLen, str!, strLen, result)
        
        
        let hash = NSData(bytes: result, length: digestLen)
        result.destroy()
        return hash
    }
    
}