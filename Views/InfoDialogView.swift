//
//  InfoDialogView.swift
//  hero4
//
//  Created by Nina Klee on 25.03.25.
//

import Foundation
import SwiftUI


//// Eine benutzerdefinierte View für den Info-Dialog
struct InfoDialogView: View {
    @Binding var isPresented: Bool
    let title: String
    let content: String
    let buttonText: String

    var body: some View {
        ZStack {
            // Abgedunkelter Hintergrund
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Schließen, wenn außerhalb getippt wird
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }

            // Dialog-Content
            VStack(spacing: 0) {
                // Header mit Titel
                VStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.gradePrimary, .gradePrimary.opacity(0.9)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(12, corners: [.topLeft, .topRight])

                // Inhalt
                VStack(alignment: .leading, spacing: 16) {
                    // Inhalt formatieren - teilen beim Aufzählungszeichen
                    ForEach(content.components(separatedBy: "• ").filter({ !$0.isEmpty }), id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            // Farbiges Bullet-Point
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.heroSecondary)
                                .font(.system(size: 18))

                            // Text
                            Text(item.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)

                // Button
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }) {
                    Text(buttonText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.heroSecondary, .heroSecondary.opacity(0.9)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
            .frame(width: min(UIScreen.main.bounds.width - 60, 400))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 30)
        }
        .opacity(isPresented ? 1 : 0)
        .scaleEffect(isPresented ? 1 : 0.8)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
    }
}


