import SwiftUI


struct PageChargement: View {
    @State private var animationAmount = 1.0
    
    @State private var navigate = false

    
    private func startAnimation(){
        withAnimation(.easeInOut(duration:1).repeatForever(autoreverses: false)){
            animationAmount += 1
        }
    }
    
    let backgroundGradient = LinearGradient(
        colors: [Color.red, Color.blue],
        startPoint: .top, endPoint: .bottom)
    
    var body: some View {
        NavigationStack{
                Text("OnFire")
                    .font(.title.bold())
                    .frame(width: 200, height: 200)
                    .background(.ultraThinMaterial,in: Circle())
                    .overlay { animatedRing }
                    .foregroundColor(.secondary)
                    .shadow(radius:7)
                    .onAppear(perform: startAnimation).task {
                        try? await Task.sleep(for: .seconds(5))
                        navigate = true
                    }.navigationDestination(isPresented: $navigate){
                        MainTabView().navigationBarBackButtonHidden(true)
                    }
        }
    }
    
    private var animatedRing: some View {
        Circle().stroke().scaleEffect(animationAmount).opacity(2 - animationAmount)
    }
}

#Preview {
    PageChargement()
}


