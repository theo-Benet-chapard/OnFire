import SwiftUI
import Charts // Nécéssaire pour le graphique

struct RechauffementVille: View {
    @State private var ville = ""
    @State private var isLoading = false
    private var nasa = NasaService()
    @State private var temp: [(key: String, value: Double)]? = nil
    @State private var dif: Double = 0.0
    
    // État pour basculer entre Grille et Graphique
    @State private var modeAffichage: ModeAffichage = .cartes

    enum ModeAffichage {
        case cartes, graphique
    }

    private let colonnes = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    TextField("Ex: Orléans", text: $ville)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    Button("Rechercher", systemImage: "magnifyingglass") {
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            do {
                                // Attention : assurez-vous de convertir 'ville' en Latitude/Longitude avant d'appeler l'API
                                (temp, dif) = try await nasa.getRechauffementVille(ville: ville)
                            } catch {
                                print("Error : \(error)")
                            }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(isLoading || ville.isEmpty)
                }
                .padding(.horizontal)

                if let temp, !temp.isEmpty {
                    Text("La température a augmenté de **\(dif, format: .number.precision(.fractionLength(2))) °C** entre la période de référence et aujourd'hui.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Picker("Mode d'affichage", selection: $modeAffichage) {
                        Text("Cartes").tag(ModeAffichage.cartes)
                        Text("Graphique").tag(ModeAffichage.graphique)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if modeAffichage == .cartes {
                        ScrollView {
                            LazyVGrid(columns: colonnes, spacing: 12) {
                                ForEach(temp, id: \.key) { item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(String(item.key.prefix(4)))
                                            .font(.headline)
                                            .foregroundStyle(.secondary)

                                        Text(String(format: "%.2f °C", item.value))
                                            .font(.title3)
                                            .bold()
                                            .foregroundStyle(item.value >= 11.5 ? .red : .blue)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Chart(temp, id: \.key) { item in
                            LineMark(
                                x: .value("Année", item.key),
                                y: .value("Température", item.value)
                            )
                            .symbol(Circle())
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }
                        .padding()
                    }
                }

                Spacer()
            }
            .navigationTitle("Réchauffement climatique")
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Chargement des données NASA...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
}
