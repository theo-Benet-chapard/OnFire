import Foundation

struct Temperature: Codable {
    let properties: Properties
}

struct Properties: Codable {
    let parameter: ParameterData
}

struct ParameterData: Codable {
    let t2m: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case t2m = "T2M"
    }
}
