//import SwiftUI
//import GRDB
//
///// A compact, unified class selection component with the app's color scheme
//struct CompactUnifiedClassSelectionView: View {
//    // Required parameters
//    let classes: [Class]
//    let selectedClassId: UUID?
//    let onClassSelected: (UUID) -> Void
//    var excludeClassId: UUID?
//    var title: String = "Klasse auswählen"
//    var showDismissButton: Bool = true
//    var onDismiss: (() -> Void)?
//    var maxWidth: CGFloat = 300  // Default max width for compact display
//
//    // Grouped classes by weekday with compact sorting
//    private var classesByWeekday: [(weekday: String, classes: [Class])] {
//        let weekdays = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]
//
//        var result: [(weekday: String, classes: [Class])] = []
//
//        for (index, weekday) in weekdays.enumerated() {
//            let column = index + 1
//            let classesForDay = classes.filter {
//                $0.column == column && !$0.isArchived &&
//                (excludeClassId == nil || $0.id != excludeClassId!)
//            }.sorted { $0.row < $1.row }
//
//            if !classesForDay.isEmpty {
//                result.append((weekday: weekday, classes: classesForDay))
//            }
//        }
//
//        return result
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // Header (only if title or dismiss button is needed)
//            if !title.isEmpty || showDismissButton {
//                HStack {
//                    Text(title)
//                        .font(.headline)
//                        .foregroundColor(.gradePrimary)
//
//                    Spacer()
//
//                    if showDismissButton {
//                        Button("Fertig") {
//                            onDismiss?()
//                        }
//                        .foregroundColor(.heroSecondary)
//                    }
//                }
//                .padding(.horizontal)
//                .padding(.vertical, 8)
//                .background(Color.white)
//            }
//
//            // Compact class list with minimal spacing
//            ScrollView {
//                VStack(spacing: 0) {
//                    ForEach(classesByWeekday, id: \.weekday) { group in
//                        // Weekday header with app color scheme
//                        Text(group.weekday)
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                            .foregroundColor(.secondary)
//                            .padding(.horizontal)
//                            .padding(.top, 12)
//                            .padding(.bottom, 4)
//                            .frame(maxWidth: .infinity, alignment: .leading)
//
//                        // Classes for this day with compact styling
//                        ForEach(group.classes) { classObj in
//                            Button(action: {
//                                onClassSelected(classObj.id)
//                            }) {
//                                HStack(spacing: 8) {
//                                    // Class name
//                                    Text(classObj.name)
//                                        .font(.headline)
//                                        .foregroundColor(.primary)
//
//                                    // Optional note with more compact styling
//                                    if let note = classObj.note, !note.isEmpty {
//                                        Text(note)
//                                            .font(.caption)
//                                            .foregroundColor(.gray)
//                                    }
//
//                                    Spacer()
//
//                                    // Checkmark using app color
//                                    if selectedClassId == classObj.id {
//                                        Image(systemName: "checkmark")
//                                            .foregroundColor(.heroSecondary)
//                                    }
//                                }
//                                .padding(.vertical, 12)
//                                .padding(.horizontal)
//                                .background(
//                                    RoundedRectangle(cornerRadius: 8)
//                                        .fill(selectedClassId == classObj.id ?
//                                             Color.heroSecondaryLight : Color.white)
//                                )
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                            .padding(.horizontal)
//                            .padding(.bottom, 2) // Minimal spacing between class items
//                        }
//                    }
//
//                    // Minimal bottom padding, just enough for good UX
//                    Spacer().frame(height: 12)
//                }
//                .background(Color(.systemGray6))
//            }
//            .frame(maxWidth: maxWidth)
//        }
//        .background(Color(.systemGray6))
//    }
//}
//
//// MARK: - Integration examples for various parts of the app
//
//// For use in ClassChangeView
//struct CompactClassChangeView: View {
//    let student: Student
//    @ObservedObject var viewModel: StudentsViewModel
//    @Binding var isPresented: Bool
//    @State private var selectedClassId: UUID?
//    @State private var isProcessing = false
//    @State private var errorMessage: String? = nil
//    @State private var showError = false
//
//    var body: some View {
//        NavigationView {
//            VStack(spacing: 0) {
//                // Error message if needed (compact version)
//                if showError, let message = errorMessage {
//                    HStack(alignment: .top, spacing: 8) {
//                        Image(systemName: "exclamationmark.triangle")
//                            .foregroundColor(.orange)
//
//                        Text(message)
//                            .font(.subheadline)
//                            .foregroundColor(.primary)
//                            .multilineTextAlignment(.leading)
//                    }
//                    .padding(12)
//                    .background(Color.orange.opacity(0.1))
//                    .cornerRadius(8)
//                    .padding([.horizontal, .top])
//                }
//
//                // Student info in compact badge style
//                HStack {
//                    Text(student.fullName)
//                        .font(.headline)
//
//                    Spacer()
//
//                    if let currentClass = viewModel.dataStore.getClass(id: student.classId) {
//                        Text(currentClass.name)
//                            .font(.subheadline)
//                            .padding(.horizontal, 8)
//                            .padding(.vertical, 4)
//                            .background(Color.gradePrimaryLight)
//                            .foregroundColor(.gradePrimary)
//                            .cornerRadius(4)
//                    }
//                }
//                .padding()
//
//                // Class selection with appropriate title
//                Text("Wählen Sie die neue Klasse:")
//                    .font(.headline)
//                    .foregroundColor(.gradePrimary)
//                    .padding(.horizontal)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//
//                // Compact unified class selection
//                CompactUnifiedClassSelectionView(
//                    classes: viewModel.classes,
//                    selectedClassId: selectedClassId,
//                    onClassSelected: { classId in
//                        selectedClassId = classId
//                    },
//                    excludeClassId: student.classId,
//                    title: "",  // No title needed, set above
//                    showDismissButton: false
//                )
//                .padding(.top, 4)
//
//                // Action buttons
//                VStack(spacing: 8) {
//                    Button(action: {
//                        moveStudentToClass()
//                    }) {
//                        if isProcessing {
//                            HStack {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle())
//                                    .padding(.trailing, 8)
//                                Text("Verschieben...")
//                            }
//                            .frame(maxWidth: .infinity, alignment: .center)
//                        } else {
//                            Text("Verschieben")
//                                .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                    }
//                    .padding()
//                    .background(selectedClassId != nil ? Color.heroSecondary : Color.gray)
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//                    .disabled(selectedClassId == nil || isProcessing)
//
//                    Button("Abbrechen") {
//                        isPresented = false
//                    }
//                    .padding()
//                    .background(Color.red.opacity(0.1))
//                    .foregroundColor(.red)
//                    .cornerRadius(8)
//                    .disabled(isProcessing)
//                }
//                .padding()
//                .background(
//                    Color.white
//                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -2)
//                )
//            }
//            .navigationTitle("Klasse wechseln")
//            .navigationBarTitleDisplayMode(.inline)
//            .navigationBarItems(trailing: Button("Schließen") {
//                isPresented = false
//            })
//            .onAppear {
//                // Automatically select the first available class
//                if let firstDay = viewModel.classesByWeekday.first,
//                   let firstClass = firstDay.classes.first(where: { $0.id != student.classId }) {
//                    selectedClassId = firstClass.id
//                }
//            }
//            .onChange(of: viewModel.showError) { oldValue, newValue in
//                if newValue {
//                    errorMessage = viewModel.errorMessage
//                    showError = true
//                }
//            }
//        }
//        .presentationDetents([.height(420), .large])
//        .presentationDragIndicator(.visible)
//    }
//
//    private func moveStudentToClass() {
//        guard let targetClassId = selectedClassId else { return }
//
//        // Validate the move
//        if let validationError = viewModel.validateMoveStudents(
//            studentIds: [student.id],
//            toClassId: targetClassId
//        ) {
//            errorMessage = validationError
//            showError = true
//            return
//        }
//
//        isProcessing = true
//
//        // Process with visual feedback
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            // Move student to new class
//            viewModel.moveStudentToClass(studentId: student.id, newClassId: targetClassId)
//
//            // Brief delay to show processing animation
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                isProcessing = false
//                isPresented = false
//            }
//        }
//    }
//}
//
//// For StudentListView - sidebar class list
//struct SidebarClassList: View {
//    @ObservedObject var viewModel: StudentsViewModel
//
//    var body: some View {
//        VStack(spacing: 0) {
//            Text("Klassen")
//                .font(.headline)
//                .padding(.top, 8)
//
//            CompactUnifiedClassSelectionView(
//                classes: viewModel.classes,
//                selectedClassId: viewModel.selectedClassId,
//                onClassSelected: { classId in
//                    viewModel.selectClass(id: classId)
//                },
//                title: "",
//                showDismissButton: false,
//                maxWidth: 250  // Match sidebar width
//            )
//            .padding(.top, 4)
//        }
//    }
//}
//
//// For Seating Plan class picker
//struct SeatingPlanClassPicker: View {
//    @ObservedObject var viewModel: EnhancedSeatingViewModel
//    @Environment(\.presentationMode) var presentationMode
//
//    var body: some View {
//        NavigationView {
//            CompactUnifiedClassSelectionView(
//                classes: viewModel.classes,
//                selectedClassId: viewModel.selectedClassId,
//                onClassSelected: { classId in
//                    viewModel.selectClass(classId)
//                    presentationMode.wrappedValue.dismiss()
//                },
//                title: "Klasse auswählen",
//                showDismissButton: true,
//                onDismiss: {
//                    presentationMode.wrappedValue.dismiss()
//                },
//                maxWidth: .infinity  // Allow full width in modal
//            )
//            .navigationBarTitle("Klasse auswählen", displayMode: .inline)
//            .navigationBarItems(trailing: Button("Fertig") {
//                presentationMode.wrappedValue.dismiss()
//            })
//        }
//    }
//}
