import SwiftUI

struct ClassChangeView: View {
    let student: Student
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var isPresented: Bool
    @State private var selectedClassId: UUID?
    @State private var isProcessing = false
    @State private var showArchiveAlert = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Schüler in andere Klasse verschieben")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(student.fullName)
                                .font(.headline)

                            if let currentClass = viewModel.dataStore.getClass(id: student.classId) {
                                Text("Aktuelle Klasse: \(currentClass.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 8)

                    Divider()

                    if viewModel.classes.count <= 1 {
                        Text("Es sind keine anderen Klassen verfügbar.")
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    } else {
                        Text("Wählen Sie die neue Klasse:")
                            .font(.headline)
                            .padding(.top, 8)

                        Picker("Neue Klasse", selection: $selectedClassId) {
                            Text("Bitte wählen").tag(nil as UUID?)
                            ForEach(viewModel.classes.filter { $0.id != student.classId }) { classObj in
                                Text(classObj.name)
                                    .tag(classObj.id as UUID?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.vertical, 8)
                    }
                }

                if showError, let message = errorMessage {
                    Section {
                        Text(message)
                            .foregroundColor(.red)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if viewModel.classes.count > 1 {
                    Section {
                        Button(action: {
                            if selectedClassId != nil {
                                // Prüfen, ob die Zielklasse voll ist
                                let studentsInTargetClass = viewModel.getStudentCountForClass(classId: selectedClassId!)
                                if studentsInTargetClass >= 40 {
                                    errorMessage = "Die Zielklasse hat bereits 40 Schüler."
                                    showError = true
                                    return
                                }

                                // Prüfen, ob der Schülername in der Zielklasse bereits existiert
                                if !viewModel.isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: selectedClassId!) {
                                    errorMessage = "Ein Schüler mit diesem Namen existiert bereits in der Zielklasse."
                                    showError = true
                                    return
                                }

                                showArchiveAlert = true
                            } else {
                                errorMessage = "Bitte wählen Sie eine Klasse aus."
                                showError = true
                            }
                        }) {
                            if isProcessing {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(.trailing, 8)
                                    Text("Verschiebe...")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("Verschieben")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(selectedClassId != nil ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .disabled(selectedClassId == nil || isProcessing)
                    }
                }

                Section {
                    Button("Abbrechen") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
                    .disabled(isProcessing)
                }
            }
            .navigationTitle("Klasse wechseln")
            .navigationBarItems(trailing: Button("Schließen") {
                isPresented = false
            })
            .onAppear {
                if let firstClass = viewModel.classes.first(where: { $0.id != student.classId }) {
                    selectedClassId = firstClass.id
                }
            }
            .alert(isPresented: $showArchiveAlert) {
                Alert(
                    title: Text("Klassenwechsel bestätigen"),
                    message: Text("Die bisherigen Noten des Schülers werden archiviert und sind in der neuen Klasse nicht mehr sichtbar. Sie können im Archiv-Tab eingesehen werden."),
                    primaryButton: .default(Text("Bestätigen")) {
                        isProcessing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.moveStudentToClass(studentId: student.id, newClassId: selectedClassId!)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isProcessing = false
                                isPresented = false
                            }
                        }
                    },
                    secondaryButton: .cancel(Text("Abbrechen")) {
                        showArchiveAlert = false
                    }
                )
            }
            .onChange(of: viewModel.showError) { oldValue, newValue in
                if newValue {
                    errorMessage = viewModel.errorMessage
                    showError = true
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
