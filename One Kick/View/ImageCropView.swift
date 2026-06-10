//
//  ImageCropView.swift
//  One Kick
//
//  Quadratischer Foto-Zuschnitt mit Verschieben + Zoomen.
//  WYSIWYG: Das im quadratischen Rahmen sichtbare Bild wird 1:1 als Ausschnitt gerendert.
//

import SwiftUI
import UIKit

/// Identifiable-Wrapper für die Präsentation via `.fullScreenCover(item:)`.
struct CropItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ImageCropView: View {
    let image: UIImage
    var outputSize: CGFloat = 400          // Ausgabe-Kantenlänge in Pixeln
    let onCancel: () -> Void
    let onCrop: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Fester quadratischer Viewport (gleicher Wert für Anzeige & Render → exaktes WYSIWYG)
    private var side: CGFloat { UIScreen.main.bounds.width }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    Spacer()

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: side, height: side)
                            .clipped()

                        // Quadratischer Rahmen als Orientierung
                        Rectangle()
                            .stroke(Color.white.opacity(0.85), lineWidth: 2)
                            .frame(width: side, height: side)
                            .allowsHitTesting(false)
                    }
                    .frame(width: side, height: side)
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1, lastScale * value)
                                }
                                .onEnded { _ in lastScale = scale },
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )

                    Text("Verschieben & zoomen zum Zuschneiden")
                        .font(.caption).foregroundColor(.gray)
                        .padding(.top, 16)

                    Spacer()
                }
            }
            .navigationTitle("Foto zuschneiden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { onCancel() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        HapticManager.instance.impact(style: .light)
                        onCrop(renderCrop())
                    }
                    .font(.headline).foregroundColor(.oneKickNeon)
                }
            }
        }
    }

    /// Rendert exakt den im Viewport sichtbaren quadratischen Ausschnitt.
    private func renderCrop() -> UIImage {
        let imgW = image.size.width
        let imgH = image.size.height
        guard imgW > 0, imgH > 0 else { return image }

        let fitScale  = side / min(imgW, imgH)   // entspricht scaledToFill in den Viewport
        let totalScale = fitScale * scale
        let drawW = imgW * totalScale
        let drawH = imgH * totalScale
        let k = outputSize / side                // Punkte → Ausgabe-Pixel

        let originX = (side / 2 - drawW / 2 + offset.width)  * k
        let originY = (side / 2 - drawH / 2 + offset.height) * k

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize)
        )
        return renderer.image { _ in
            image.draw(in: CGRect(x: originX, y: originY, width: drawW * k, height: drawH * k))
        }
    }
}
