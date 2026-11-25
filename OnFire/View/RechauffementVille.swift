import SwiftUI
import MapKit
import CoreLocation
import Combine

// Choisir entre la Map ou le Graphic
enum Visuel: String, CaseIterable, Identifiable {
    case map = "Maps", graph = "Graphics"
    var id: Self { self }
}

// Partie pour la localisation
class Location: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate
        manager.stopUpdatingLocation()
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// La view du Graphic
struct BarsCanvas: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard !values.isEmpty else { return }
            
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let range = max(maxVal - minVal, 0.001)
            
            let gap: CGFloat = 2
            let totalGaps = gap * CGFloat(max(0, values.count - 1))
            let width = max(1, (size.width - totalGaps) / CGFloat(values.count))
            
            for (i, v) in values.enumerated() {
                let normalized = (v - minVal) / range
                let h = max(4, size.height * CGFloat(normalized))
                
                let rect = CGRect(
                    x: CGFloat(i) * (width + gap),
                    y: size.height - h,
                    width: width,
                    height: h
                )
                
                let color: Color = normalized > 0.5 ? .orange : .blue
                
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(width / 3, 2)),
                    with: .color(color)
                )
            }
        }
        .frame(height: 180)
    }
}

struct GraphView: View {
    let temp: [(key: String, value: Double)]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Évolution (1981 - 2026)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if let tempValues = temp, !tempValues.isEmpty {
                    BarsCanvas(values: tempValues.map { $0.value })
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                } else {
                    Text("Aucune donnée chargée. Effectuez une recherche.")
                        .foregroundColor(.secondary)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
        }
    }
}

// Page principale
struct RechauffementVille: View {
    
    // Valeur de défaut si la localisation échoue
    private let lon_def: Double = 1.909251
    private let lat_def: Double = 47.902964
    
    // Variables indispensables pour la page
    @State private var select: Visuel = .map
    @State private var isLoading = false
    
    // Structs et Variable pour la partie affichage et recherche
    @State private var ville: Ville
    @State private var searchText: String = ""
    private let nasa = NasaService()
    private let nominatim = NominatimService()
    @State private var dif: Double = 0.0
    
    // Variable pour la localisation et Maps
    private let locationManager = Location()
    @State private var cameraPosition: MapCameraPosition
    
    // Variables pour les Graphs
    @State private var progress = 0.0
    @State private var temp: [(key: String, value: Double)]? = nil
    
    // Initialisation corrigée (toutes les propriétés sont initialisées avant d'utiliser des méthodes)
    init(ville: Ville = Ville(lat: "47.902964", lon: "1.909251", name: "Orléans")) {
        _ville = State(initialValue: ville)
        _searchText = State(initialValue: ville.name)
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: Double(ville.lat) ?? 47.902964,
                    longitude: Double(ville.lon) ?? 1.909251
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        ))
    }

    var body: some View {
        VStack {
            Text("Réchauffement climatique").font(.title).bold()
            
            Text("A \(ville.name) a une différence de \(String(format: "%.2f", dif)) depuis 1981")
            
            Picker("Niveau", selection: $select) {
                ForEach(Visuel.allCases) { visuel in
                    Text(visuel.rawValue).tag(visuel)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            HStack {
                TextField("Ex: Orléans", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textContentType(.name)
                
                Button {
                    Action()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 100))
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
            }.padding(.horizontal)
            
            if select == .map {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        Marker(ville.name, coordinate: CLLocationCoordinate2D(latitude: Double(ville.lat) ?? lat_def, longitude: Double(ville.lon) ?? lon_def))
                            .tint(.red)
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.8)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onEnded { value in
                                guard case .second(_, let dragValue?) = value else { return }
                                let location = dragValue.location
                                
                                if let coordinate = proxy.convert(location, from: .local) {
                                    Task {
                                        isLoading = true
                                        defer { isLoading = false }
                                        do {
                                            if let nouvelleVille = try await nominatim.getVilleParCoordonnees(lat: coordinate.latitude, lon: coordinate.longitude) {
                                                ville = nouvelleVille
                                                searchText = nouvelleVille.name
                                                (temp, dif) = try await nasa.getRechauffementVille(ville: ville)
                                                MajCamera()
                                            }
                                        } catch {
                                            print("Erreur appui long carte : \(error)")
                                        }
                                    }
                                }
                            }
                    )
                }
            } else {
                GraphView(temp: temp)
            }
            
            Spacer()
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Chargement...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        .task(id: searchText) {
            await ChargerVille()
            guard !searchText.isEmpty, searchText != ville.name else { return }
            
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            
            isLoading = true
            defer { isLoading = false }
            do {
                if let resultatVille = try await nominatim.getVille(ville: searchText) {
                    ville = resultatVille
                    (temp, dif) = try await nasa.getRechauffementVille(ville: ville)
                    MajCamera()
                }
            } catch {
                print("Erreur recherche API : \(error)")
            }
        }
        .onChange(of: locationManager.userLocation) { newLocation in
            if let coordinate = newLocation {
                Task {
                    await ChargerVilleCoordonnees(lat: coordinate.latitude, lon: coordinate.longitude)
                    MajCamera()
                }
            }
        }
    }
    
    private func ChargerVille() async {
        isLoading = true
        defer { isLoading = false }
        do {
            (temp, dif) = try await nasa.getRechauffementVille(ville: ville)
        } catch {
            print("Erreur chargement initial NASA : \(error)")
        }
    }
    
    private func ChargerVilleCoordonnees(lat: Double, lon: Double) async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let nouvelleVille = try await nominatim.getVilleParCoordonnees(lat: lat, lon: lon) {
                ville = nouvelleVille
                searchText = nouvelleVille.name
                (temp, dif) = try await nasa.getRechauffementVille(ville: ville)
            }
        } catch {
            print("Erreur chargement coordonnées : \(error)")
        }
    }
    
    private func Action() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                if let resultatVille = try await nominatim.getVille(ville: searchText) {
                    ville = resultatVille
                    (temp, dif) = try await nasa.getRechauffementVille(ville: ville)
                    MajCamera()
                }
            } catch {
                print("Error : \(error)")
            }
        }
    }
    
    private func MajCamera() {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: Double(ville.lat) ?? lat_def,
                    longitude: Double(ville.lon) ?? lon_def
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    }
}
