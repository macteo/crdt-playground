//
//  ORDTOperation.swift
//  CRDTPlayground
//
//  Created by Alexei Baboulevitch on 2018-4-17.
//  Copyright © 2018 Alexei Baboulevitch. All rights reserved.
//

import Foundation

public struct OperationID
{
    /// 5 bytes for the clock, 2 bytes for the site ID, 1 byte for the instance ID.
    private var data: UInt64
    
    // TODO: handle endianness, etc.
    public init(logicalTimestamp: Clock, siteID: SiteId, instanceID: UInt8? = nil)
    {
        precondition(logicalTimestamp <= Clock(pow(2.0, 8 * 5)) - 1, "the logical timestamp needs to fit into 5 bytes")
        
        // TODO: make the types unsigned
        precondition(logicalTimestamp >= 0)
        precondition(siteID >= 0)
        
        var data: UInt64 = 0
        
        data |= UInt64(logicalTimestamp) & 0xffffffffff
        data <<= (2 * 8)
        data |= UInt64(siteID) & 0xffff
        data <<= (1 * 8)
        data |= UInt64(instanceID ?? 0) & 0xff
        
        self.data = data
    }
    
    /// The logical clock value, preferably a HLC or Lamport timestamp. Treated as a UInt40, which should be more than
    /// enough for practical use.
    public var logicalTimestamp: Clock
    {
        return Clock((self.data >> (3 * 8)) & 0xffffffffff)
    }
    
    /// The local site ID. Mappable to a UUID with the help of a Site Map.
    public var siteID: SiteId
    {
        return SiteId((self.data >> (1 * 8)) & 0xffff)
    }
    
    /// An additional byte of ordering data. This is useful if, for instance, you make several copies of the ORDT
    /// for use with multiple threads. Instead of wastefully giving each copy its own UUID, this is a far more
    /// space-efficient solution.
    public var instanceID: UInt8
    {
        return UInt8((self.data >> (0 * 8)) & 0xff)
    }
}
extension OperationID: Equatable, Comparable, Hashable
{
    public static func ==(lhs: OperationID, rhs: OperationID) -> Bool
    {
        return lhs.data == rhs.data
    }
    
    public static func <(lhs: OperationID, rhs: OperationID) -> Bool
    {
        return lhs.data < rhs.data
    }
    
    public var hashValue: Int
    {
        return self.data.hashValue
    }
}

public struct Operation
    <ValueT: DefaultInitializable & IndexRemappable>
    : OperationType, CustomStringConvertible, IndexRemappable
{
    public private(set) var id: OperationID
    public private(set) var value: ValueT
    
    public init(id: OperationID, value: ValueT)
    {
        self.id = id
        self.value = value
    }
    
    public var description: String
    {
        get
        {
            return "\(id)"
        }
    }
    
    public var debugDescription: String
    {
        get
        {
            return "\(id): \(value)"
        }
    }
    
    public mutating func remapIndices(_ map: [SiteId:SiteId])
    {
        if let newOwner = map[self.id.siteID]
        {
            self.id = OperationID.init(logicalTimestamp: self.id.logicalTimestamp, siteID: newOwner, instanceID: self.id.instanceID)
        }
        
        value.remapIndices(map)
    }
}