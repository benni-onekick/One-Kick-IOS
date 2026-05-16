import SwiftUI

struct JoinChallengeView: View {
    @EnvironmentObject var manager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    @State private var challengeName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                
                VStack(spacing: 25) {
                    
                    Text("Neue Liga starten")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    // Design Icon
                    Image(systemName: "trophy.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.oneKickNeon)
                        .padding(.bottom, 10)
                    
                    // Eingabe
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name der Liga")
                            .font(.caption).foregroundColor(.gray).padding(.leading, 4)
                        
                        TextField("z.B. Bürogemeinschaft", text: $challengeName)
                            .padding()
                            .background(Color.oneKickDarkGray)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }.padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                        if !challengeName.isEmpty {
                            manager.createAndOpen(name: challengeName)
                            dismiss()
                        }
                    }) {
                        Text("Liga erstellen & öffnen")
                            .font(.headline).bold()
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(challengeName.isEmpty ? Color.gray : Color.oneKickNeon)
                            .cornerRadius(12)
                    }
                    .disabled(challengeName.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }.foregroundColor(.white)
                    }
                }
            }
        }
    }
}
