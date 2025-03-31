import SwiftUI

struct MultiSelectActionBar: View {
    // Required bindings from parent view
    @Binding var selectedStudents: Set<UUID>
    @Binding var showClassChangeForSelectedStudents: Bool
    @Binding var editMode: EditMode
    @Binding var showOperationsView: Bool // For operations modal
    @Binding var showOperationsSheet: Bool // For operations sheet

    // ViewModel for data operations
    @ObservedObject var viewModel: StudentsViewModel

    // Internal state
    @State private var isProcessing = false

    var body: some View {
        VStack {
            Divider()

            HStack(spacing: 16) {
                // A single unified button for all operations
                Button(action: {
                    if !selectedStudents.isEmpty {
                        showOperationsView = true
                    }
                }) {
                    HStack {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 16))
                        Text("Operationen")
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)
                    .foregroundColor(.blue)
                }
                .disabled(selectedStudents.isEmpty || isProcessing)

                Button(action: {
                    showOperationsSheet = true
                }) {
                    HStack {
                        Image(systemName: "ellipsis.circle.fill")
                        Text("Mehr Optionen")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)
                }

                Spacer()

                Text("\(selectedStudents.count) ausgewählt")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 8)

                Button(action: {
                    editMode = .inactive
                    selectedStudents.removeAll()
                }) {
                    Text("Beenden")
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .disabled(isProcessing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }
}
