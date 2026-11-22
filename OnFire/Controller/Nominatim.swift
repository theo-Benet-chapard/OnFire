import Foundation

class NominatimService {
    func getVille(ville: String) async throws -> Ville? {
        let url = URL(string: "https://nominatim.openstreetmap.org/search?q=\(ville)&format=jsonv2&limit=1")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
         let result = try JSONDecoder().decode([Ville].self, from: data)
        
        return result.first
    }
}
