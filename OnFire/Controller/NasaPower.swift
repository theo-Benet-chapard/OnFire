import SwiftUI

import Foundation


class NasaService {
    private var nominatime = NominatimService()
    
    func getRechauffementVille(ville: String) async throws -> (donnees: [(key: String, value: Double)], difference: Double) {
        
        let v = try await nominatime.getVille(ville: ville)!
        
        let url = URL(string: "https://power.larc.nasa.gov/api/temporal/monthly/point?parameters=T2M&community=RE&longitude=\(v.lon)&latitude=\(v.lat)&start=1981&end=2026&format=JSON")!
        
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let result =  try JSONDecoder().decode(Temperature.self, from: data)
        
        let donneesTriees = result.properties.parameter.t2m
            .filter { $0.key.hasSuffix("13") && $0.value > -900 }
            .sorted { $0.key > $1.key }
        let dif = (donneesTriees.first?.value ?? 0.0) - (donneesTriees.last?.value ?? 0.0)
        
        return (donneesTriees,dif)
    }
}
