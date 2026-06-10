//
//  CreateGlobalPollView.swift
//  One Kick
//
//  Entwickler-Formular zum Erstellen app-weiter Umfragen. Nur für den
//  Entwickler-Account erreichbar (Aufrufer prüft GlobalPollViewModel.isDeveloper).
//

import SwiftUI

struct CreateGlobalPollView: View {

    @ObservedObject var viewModel: GlobalPollViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var options: [String] = ["", ""]
    @State private var multiSelect = false
    @State private var endsAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    private var trimmedOptions: [String] {
        options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var canCreate: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty
            && trimmedOptions.count >= 2
            && endsAt > Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.oneKickBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {

                        // Frage
                        section("Frage") {
                            TextField("z. B. Wird Arsenal Meister?", text: $question, axis: .vertical)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.oneKickDarkGray)
                                .cornerRadius(10)
                        }

                        // Optionen
                        section("Antwortmöglichkeiten") {
                            VStack(spacing: 8) {
                                ForEach(options.indices, id: \.self) { i in
                                    HStack(spacing: 8) {
                                        TextField("Option \(i + 1)", text: $options[i])
                                            .textFieldStyle(.plain)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Color.oneKickDarkGray)
                                            .cornerRadius(10)
                                        if options.count > 2 {
                                            Button {
                                                options.remove(at: i)
                                            } label: {
                                                Image(systemName: "minus.circle.fill").foregroundColor(.red.opacity(0.8))
                                            }
                                        }
                                    }
                                }
                                Button {
                                    options.append("")
                                } label: {
                                    Label("Option hinzufügen", systemImage: "plus.circle")
                                        .font(.system(size: 14)).foregroundColor(.oneKickNeon)
                                }
                                .padding(.top, 2)
                            }
                        }

                        // Mehrfachauswahl
                        Toggle(isOn: $multiSelect) {
                            Text("Mehrfachauswahl erlauben").foregroundColor(.white).font(.subheadline)
                        }
                        .tint(.oneKickNeon)

                        // Aktiv bis
                        section("Aktiv bis") {
                            DatePicker("", selection: $endsAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(.oneKickNeon)
                        }

                        Button {
                            viewModel.createPoll(
                                question: question.trimmingCharacters(in: .whitespaces),
                                options: trimmedOptions,
                                multiSelect: multiSelect,
                                endsAt: endsAt
                            )
                            dismiss()
                        } label: {
                            Text("Umfrage erstellen")
                                .font(.headline).bold().foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(canCreate ? Color.oneKickNeon : Color.gray.opacity(0.3))
                                .cornerRadius(12)
                        }
                        .disabled(!canCreate)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Neue Abstimmung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold)).foregroundColor(.gray).tracking(0.5)
            content()
        }
    }
}
